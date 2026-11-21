/*
 * Audio engine for the wh01s17.metronome shell plugin.
 *
 * Timing lives here, not in QML, and not on the wall clock either. The click
 * track is synthesised inside PipeWire's realtime process callback, one
 * buffer per graph cycle, so the frame counter that places every pulse *is*
 * the playback clock of the device. Nothing paces the audio but the device:
 * no pipe to fill, no sleep to oversleep, no second clock to drift against.
 * The callback runs on PipeWire's data thread, which libpipewire raises to
 * realtime priority (RTKit), so CPU load elsewhere does not delay it, and the
 * work it does per cycle is a few multiply-adds per sounding sample.
 *
 * Pulses are placed with sub-sample precision: each click starts at the exact
 * fractional frame where its beat falls, so tempos whose beat length is not a
 * whole number of frames neither jitter nor drift.
 *
 * Protocol
 *   stdin   one JSON object per line, any subset of the state keys:
 *           {"running": true, "bpm": 120, "beats": 4, "subdivision": "1/8",
 *            "volume": 0.7, "accent": true}
 *           Unknown keys are ignored; {"quit": true} or EOF exits.
 *   stdout  one JSON event per line, emitted when the pulse becomes
 *           *audible* (device latency included) rather than when rendered:
 *           {"e":"beat","beat":0,"pulse":0,"accent":true,"downbeat":true,"bpm":120}
 *   stderr  human-readable diagnostics only.
 *
 * The stream stays open while stopped and renders silence: tearing it down
 * would make the next start pay the connection latency as a late first click.
 * MetronomeCore ends the process after a while idle.
 *
 * Built on first use by metronome-engine.sh.
 */

#define _GNU_SOURCE
#include <errno.h>
#include <math.h>
#include <pthread.h>
#include <signal.h>
#include <stdatomic.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/resource.h>
#include <time.h>
#include <unistd.h>

#include <pipewire/impl-module.h>
#include <pipewire/pipewire.h>
#include <spa/param/audio/format-utils.h>

#define RATE 48000
#define MAX_VOICES 32
#define EVENT_RING 256          /* power of two */
#define OUTPUT_GAIN 0.97f

/* Pulse offsets inside one beat, as fractions of the beat. */
struct subdivision {
	const char *name;
	int count;
	double offsets[6];
};

static const struct subdivision SUBDIVISIONS[] = {
	{ "1/4",   1, { 0.0 } },
	{ "1/8",   2, { 0.0, 1.0 / 2.0 } },
	{ "1/8t",  3, { 0.0, 1.0 / 3.0, 2.0 / 3.0 } },
	{ "1/16",  4, { 0.0, 1.0 / 4.0, 2.0 / 4.0, 3.0 / 4.0 } },
	{ "1/16t", 6, { 0.0, 1.0 / 6.0, 2.0 / 6.0, 3.0 / 6.0, 4.0 / 6.0, 5.0 / 6.0 } },
	{ "swing", 2, { 0.0, 2.0 / 3.0 } },
};
#define N_SUBDIVISIONS (int)(sizeof SUBDIVISIONS / sizeof SUBDIVISIONS[0])

/* An exponentially decaying sine. The tail runs to seven time constants
 * (-60 dB), so a click never ends on an audible step. */
struct voice_shape {
	double freq;   /* Hz */
	double amp;
	double decay;  /* time constant, s */
};

static const struct voice_shape VOICE_ACCENT = { 1560.0, 1.00, 0.016 };
static const struct voice_shape VOICE_BEAT   = { 1040.0, 0.72, 0.018 };
static const struct voice_shape VOICE_SUB    = { 2080.0, 0.30, 0.008 };

/* ------------------------------------------------------------------ state */

/* What the main thread asks for. Copied into the realtime thread whole. */
struct control {
	bool running;
	double bpm;
	int beats;
	int subdivision;     /* index into SUBDIVISIONS */
	double volume;
	bool accent;
	uint32_t gen;        /* bumped on every start, tags the events it causes */
};

struct voice {
	bool active;
	bool started;
	double start;        /* exact (fractional) frame the click begins at */
	uint64_t end;        /* first frame past the tail */
	double amp;
	double rot_re, rot_im;   /* per-sample rotation: e^{(-1/τ + iω)/RATE} */
	double z_re, z_im;       /* current phasor; the output is its imaginary part */
	double k_decay, k_omega; /* -1/(τ·RATE) and ω/RATE, for the first sample */
};

struct event {
	uint64_t when_ns;    /* CLOCK_MONOTONIC */
	uint32_t gen;
	int beat, pulse;
	bool accent, downbeat;
	double bpm;
};

struct engine {
	struct pw_main_loop *main_loop;
	struct pw_loop *loop;
	struct pw_context *context;
	struct pw_core *core;
	struct pw_stream *stream;
	struct spa_hook stream_listener;
	struct spa_source *stdin_source;
	struct spa_source *event_source;
	struct spa_source *timer_source;
	int exit_code;
	bool quitting;

	/* main thread → realtime thread */
	pthread_mutex_t control_lock;
	struct control pending;
	uint32_t pending_seq;

	/* realtime thread only */
	struct control ctl;
	uint32_t applied_seq;
	uint64_t pos;            /* absolute frame cursor of the next buffer */
	double beat_start;       /* frame where the current beat begins */
	double beat_len;         /* frames per beat, latched at the beat */
	int beat_index;
	int pulse_index;
	const struct subdivision *beat_sub;  /* latched at the beat */
	bool have_clock;
	double clock_offset_ns;  /* smoothed: audible time of frame 0 */
	struct voice voices[MAX_VOICES];

	/* realtime thread → main thread: single-producer single-consumer ring */
	struct event events[EVENT_RING];
	_Atomic uint32_t ev_head;   /* written by the realtime thread */
	_Atomic uint32_t ev_tail;   /* written by the main thread */

	/* main thread only */
	struct control want;
	char line[4096];
	size_t line_len;
};

static uint64_t monotonic_ns(void)
{
	struct timespec ts;
	clock_gettime(CLOCK_MONOTONIC, &ts);
	return (uint64_t)ts.tv_sec * SPA_NSEC_PER_SEC + (uint64_t)ts.tv_nsec;
}

static bool control_equal(const struct control *a, const struct control *b)
{
	return a->running == b->running && a->bpm == b->bpm && a->beats == b->beats &&
	       a->subdivision == b->subdivision && a->volume == b->volume &&
	       a->accent == b->accent && a->gen == b->gen;
}

static double clamp(double v, double lo, double hi)
{
	return v < lo ? lo : v > hi ? hi : v;
}

static double beat_frames(double bpm)
{
	return RATE * 60.0 / clamp(bpm, 20.0, 400.0);
}

/* -------------------------------------------------------- realtime thread */

static void add_voice(struct engine *e, const struct voice_shape *shape, double start)
{
	struct voice *v = NULL;
	for (int i = 0; i < MAX_VOICES; i++)
		if (!e->voices[i].active) { v = &e->voices[i]; break; }
	if (!v) {
		/* Out of voices (cannot happen at the tempos the UI allows):
		 * replace the one that started first, it is the quietest. */
		v = &e->voices[0];
		for (int i = 1; i < MAX_VOICES; i++)
			if (e->voices[i].start < v->start) v = &e->voices[i];
	}

	double k_decay = -1.0 / (shape->decay * RATE);
	double k_omega = 2.0 * M_PI * shape->freq / RATE;
	*v = (struct voice) {
		.active = true,
		.start = start,
		.end = (uint64_t)ceil(start + 7.0 * shape->decay * RATE),
		.amp = shape->amp * e->ctl.volume,
		.rot_re = exp(k_decay) * cos(k_omega),
		.rot_im = exp(k_decay) * sin(k_omega),
		.k_decay = k_decay,
		.k_omega = k_omega,
	};
}

static void push_event(struct engine *e, const struct event *ev)
{
	uint32_t head = atomic_load_explicit(&e->ev_head, memory_order_relaxed);
	uint32_t tail = atomic_load_explicit(&e->ev_tail, memory_order_acquire);
	if (head - tail >= EVENT_RING)
		return;  /* nobody is reading; the sound matters, the light can drop */
	e->events[head & (EVENT_RING - 1)] = *ev;
	atomic_store_explicit(&e->ev_head, head + 1, memory_order_release);
}

static void latch_beat(struct engine *e)
{
	e->beat_len = beat_frames(e->ctl.bpm);
	e->beat_sub = &SUBDIVISIONS[e->ctl.subdivision];
	e->pulse_index = 0;
}

static void apply_control(struct engine *e)
{
	/* Never wait on the main thread: if it holds the lock right now, the
	 * change lands one cycle later. */
	if (pthread_mutex_trylock(&e->control_lock) != 0)
		return;
	bool fresh = e->pending_seq != e->applied_seq;
	struct control next = e->pending;
	e->applied_seq = e->pending_seq;
	pthread_mutex_unlock(&e->control_lock);
	if (!fresh)
		return;

	bool starting = next.running && (!e->ctl.running || next.gen != e->ctl.gen);
	e->ctl = next;
	if (starting) {
		/* The downbeat is the first frame of this very buffer. */
		e->beat_start = (double)e->pos;
		e->beat_index = 0;
		latch_beat(e);
	}
	/* On stop, the clicks already sounding ring out instead of being cut
	 * mid-waveform; no new ones are scheduled. */
}

/* Queue every pulse that starts before frame `until`. Tempo, subdivision and
 * bar length take effect on the next beat, never mid-beat: changing the beat
 * under a pulse already placed would swallow or double it. */
static void schedule(struct engine *e, uint64_t until, uint64_t buf_ns, double ns_per_frame)
{
	while (e->ctl.running) {
		if (e->pulse_index >= e->beat_sub->count) {
			e->beat_start += e->beat_len;
			e->beat_index = e->beat_index + 1 >= e->ctl.beats ? 0 : e->beat_index + 1;
			latch_beat(e);
			continue;
		}

		double frame = e->beat_start + e->beat_sub->offsets[e->pulse_index] * e->beat_len;
		if (frame >= (double)until)
			return;

		bool downbeat = e->pulse_index == 0;
		bool accented = downbeat && e->beat_index == 0 && e->ctl.accent;
		add_voice(e, accented ? &VOICE_ACCENT : downbeat ? &VOICE_BEAT : &VOICE_SUB, frame);

		double ahead = frame - (double)e->pos;
		struct event ev = {
			.when_ns = buf_ns + (uint64_t)(ahead > 0 ? ahead * ns_per_frame : 0),
			.gen = e->ctl.gen,
			.beat = e->beat_index,
			.pulse = e->pulse_index,
			.accent = accented,
			.downbeat = downbeat,
			.bpm = e->ctl.bpm,
		};
		push_event(e, &ev);
		e->pulse_index++;
	}
}

static void render(struct engine *e, float *out, uint32_t n)
{
	memset(out, 0, n * sizeof(float));
	uint64_t pos = e->pos;

	for (int i = 0; i < MAX_VOICES; i++) {
		struct voice *v = &e->voices[i];
		if (!v->active)
			continue;
		if (v->end <= pos) {
			v->active = false;
			continue;
		}

		uint32_t first = 0;
		if (!v->started) {
			double lead = ceil(v->start - (double)pos);
			if (lead >= n)
				continue;  /* starts in a later buffer */
			first = lead > 0 ? (uint32_t)lead : 0;
			/* Phase and envelope at the first whole frame on or after
			 * the exact start, so the click begins between samples. */
			double t = (double)(pos + first) - v->start;
			double env = v->amp * exp(v->k_decay * t);
			v->z_re = env * cos(v->k_omega * t);
			v->z_im = env * sin(v->k_omega * t);
			v->started = true;
		}

		uint64_t stop = v->end - pos;
		uint32_t last = stop < n ? (uint32_t)stop : n;
		double re = v->z_re, im = v->z_im;
		const double rr = v->rot_re, ri = v->rot_im;
		for (uint32_t k = first; k < last; k++) {
			out[k] += (float)im;
			double nre = re * rr - im * ri;
			im = re * ri + im * rr;
			re = nre;
		}
		v->z_re = re;
		v->z_im = im;
		if (last < n)
			v->active = false;
	}

	for (uint32_t k = 0; k < n; k++) {
		float s = out[k] * OUTPUT_GAIN;
		out[k] = s > 1.0f ? 1.0f : s < -1.0f ? -1.0f : s;
	}
}

static void on_process(void *data)
{
	struct engine *e = data;
	struct pw_buffer *b = pw_stream_dequeue_buffer(e->stream);
	if (!b)
		return;

	struct spa_data *d = &b->buffer->datas[0];
	float *out = d->data;
	if (!out) {
		pw_stream_queue_buffer(e->stream, b);
		return;
	}
	uint32_t n = d->maxsize / sizeof(float);
	if (b->requested && b->requested < n)
		n = (uint32_t)b->requested;

	/* When does the first frame of this buffer reach the speaker? Each
	 * cycle's own answer wobbles by the driver's wakeup jitter, so it is
	 * smoothed into one steady frame→time line; a jump of more than a few
	 * milliseconds (a new sink, a resync) is taken at once. This only
	 * steers the light in the bar — the sound never depends on it. */
	const double ns_per_frame = (double)SPA_NSEC_PER_SEC / RATE;
	struct pw_time t;
	double audible_ns = (double)monotonic_ns();
	if (pw_stream_get_time_n(e->stream, &t, sizeof t) == 0 && t.now > 0) {
		audible_ns = (double)t.now;
		if (t.rate.denom > 0 && t.delay > 0)
			audible_ns += (double)t.delay * SPA_NSEC_PER_SEC * t.rate.num / t.rate.denom;
		audible_ns += (double)t.buffered * ns_per_frame;
	}
	double offset = audible_ns - (double)e->pos * ns_per_frame;
	if (!e->have_clock || fabs(offset - e->clock_offset_ns) > 4e6) {
		e->clock_offset_ns = offset;
		e->have_clock = true;
	} else {
		e->clock_offset_ns += 0.02 * (offset - e->clock_offset_ns);
	}
	uint64_t buf_ns = (uint64_t)(e->clock_offset_ns + (double)e->pos * ns_per_frame);

	apply_control(e);
	uint32_t before = atomic_load_explicit(&e->ev_head, memory_order_relaxed);
	schedule(e, e->pos + n, buf_ns, ns_per_frame);
	render(e, out, n);
	e->pos += n;

	d->chunk->offset = 0;
	d->chunk->stride = sizeof(float);
	d->chunk->size = n * sizeof(float);
	pw_stream_queue_buffer(e->stream, b);

	if (atomic_load_explicit(&e->ev_head, memory_order_relaxed) != before)
		pw_loop_signal_event(e->loop, e->event_source);
}

/* ------------------------------------------------------------ main thread */

/* Releases every event that is due and arms the timer for the next one. */
static void flush_events(struct engine *e)
{
	uint64_t now = monotonic_ns();
	for (;;) {
		uint32_t tail = atomic_load_explicit(&e->ev_tail, memory_order_relaxed);
		uint32_t head = atomic_load_explicit(&e->ev_head, memory_order_acquire);
		if (tail == head) {
			pw_loop_update_timer(e->loop, e->timer_source, NULL, NULL, false);
			return;
		}
		struct event *ev = &e->events[tail & (EVENT_RING - 1)];
		/* A stop, or a restart, voids what the previous run queued. */
		bool stale = !e->want.running || ev->gen != e->want.gen;
		if (!stale && ev->when_ns > now + 500000) {
			struct timespec ts = {
				.tv_sec = (time_t)(ev->when_ns / SPA_NSEC_PER_SEC),
				.tv_nsec = (long)(ev->when_ns % SPA_NSEC_PER_SEC),
			};
			pw_loop_update_timer(e->loop, e->timer_source, &ts, NULL, true);
			return;
		}
		if (!stale) {
			printf("{\"e\":\"beat\",\"beat\":%d,\"pulse\":%d,\"accent\":%s,"
			       "\"downbeat\":%s,\"bpm\":%g}\n",
			       ev->beat, ev->pulse, ev->accent ? "true" : "false",
			       ev->downbeat ? "true" : "false", ev->bpm);
			if (fflush(stdout) != 0) {
				pw_main_loop_quit(e->main_loop);
				return;
			}
		}
		atomic_store_explicit(&e->ev_tail, tail + 1, memory_order_release);
	}
}

static void on_events(void *data, uint64_t count)
{
	(void)count;
	flush_events(data);
}

static void on_timer(void *data, uint64_t expirations)
{
	(void)expirations;
	flush_events(data);
}

/* Finds "key" in a flat JSON object and returns the text after its colon. */
static const char *json_value(const char *line, const char *key)
{
	char quoted[64];
	snprintf(quoted, sizeof quoted, "\"%s\"", key);
	const char *p = strstr(line, quoted);
	if (!p)
		return NULL;
	p += strlen(quoted);
	while (*p == ' ' || *p == '\t') p++;
	if (*p != ':')
		return NULL;
	p++;
	while (*p == ' ' || *p == '\t') p++;
	return p;
}

static bool json_number(const char *line, const char *key, double *out)
{
	const char *p = json_value(line, key);
	if (!p)
		return false;
	char *end;
	errno = 0;
	double v = strtod(p, &end);
	if (end == p || errno != 0 || !isfinite(v))
		return false;
	*out = v;
	return true;
}

static bool json_bool(const char *line, const char *key, bool *out)
{
	const char *p = json_value(line, key);
	if (!p)
		return false;
	if (strncmp(p, "true", 4) == 0) { *out = true; return true; }
	if (strncmp(p, "false", 5) == 0) { *out = false; return true; }
	return false;
}

static bool json_string(const char *line, const char *key, char *out, size_t size)
{
	const char *p = json_value(line, key);
	if (!p || *p != '"')
		return false;
	p++;
	size_t len = strcspn(p, "\"");
	if (p[len] != '"' || len >= size)
		return false;
	memcpy(out, p, len);
	out[len] = '\0';
	return true;
}

static void handle_line(struct engine *e, const char *line)
{
	struct control c = e->want;
	double num;
	bool flag;
	char name[16];

	if (json_bool(line, "quit", &flag) && flag) {
		pw_main_loop_quit(e->main_loop);
		return;
	}
	if (json_number(line, "bpm", &num))
		c.bpm = clamp(num, 20.0, 400.0);
	if (json_number(line, "beats", &num))
		c.beats = (int)clamp(round(num), 1, 32);
	if (json_string(line, "subdivision", name, sizeof name))
		for (int i = 0; i < N_SUBDIVISIONS; i++)
			if (strcmp(SUBDIVISIONS[i].name, name) == 0)
				c.subdivision = i;
	if (json_number(line, "volume", &num))
		c.volume = clamp(num, 0.0, 1.0);
	if (json_bool(line, "accent", &flag))
		c.accent = flag;
	if (json_bool(line, "running", &flag) && flag != c.running) {
		c.running = flag;
		if (flag)
			c.gen++;
	}

	bool changed = !control_equal(&c, &e->want);
	e->want = c;
	if (!changed)
		return;

	pthread_mutex_lock(&e->control_lock);
	e->pending = c;
	e->pending_seq++;
	pthread_mutex_unlock(&e->control_lock);

	if (!c.running)
		flush_events(e);  /* drops what is still queued */
}

static void on_stdin(void *data, int fd, uint32_t mask)
{
	struct engine *e = data;

	if (mask & SPA_IO_IN) {
		char buf[1024];
		ssize_t got = read(fd, buf, sizeof buf);
		if (got < 0 && (errno == EAGAIN || errno == EINTR))
			return;
		if (got <= 0) {
			pw_main_loop_quit(e->main_loop);
			return;
		}
		for (ssize_t i = 0; i < got; i++) {
			if (buf[i] == '\n') {
				e->line[e->line_len] = '\0';
				handle_line(e, e->line);
				e->line_len = 0;
			} else if (e->line_len + 1 < sizeof e->line) {
				e->line[e->line_len++] = buf[i];
			}
		}
		return;
	}
	if (mask & (SPA_IO_HUP | SPA_IO_ERR))
		pw_main_loop_quit(e->main_loop);
}

static void on_state_changed(void *data, enum pw_stream_state old,
			     enum pw_stream_state state, const char *error)
{
	struct engine *e = data;
	(void)old;
	if (e->quitting)
		return;
	if (state == PW_STREAM_STATE_ERROR) {
		fprintf(stderr, "stream error: %s\n", error ? error : "unknown");
		e->exit_code = 1;
		pw_main_loop_quit(e->main_loop);
	} else if (state == PW_STREAM_STATE_UNCONNECTED) {
		fprintf(stderr, "stream disconnected\n");
		e->exit_code = 1;
		pw_main_loop_quit(e->main_loop);
	}
}

static const struct pw_stream_events stream_events = {
	PW_VERSION_STREAM_EVENTS,
	.state_changed = on_state_changed,
	.process = on_process,
};

static void on_quit(void *data, int signal_number)
{
	(void)signal_number;
	struct engine *e = data;
	pw_main_loop_quit(e->main_loop);
}

int main(int argc, char *argv[])
{
	static struct engine e;  /* large; keep it off the stack */
	const char *sink = getenv("WH01S17_METRONOME_SINK");

	/* Preferred output sink. "Compartido" is a virtual sink defined by
	 * evo8-linux that plays on the selected output *and* feeds the Mezcla
	 * virtual microphone, so the click is heard locally and sent wherever
	 * that microphone goes. When no sink by that name exists, WirePlumber
	 * falls back to the default output, so the metronome is never left
	 * silent. An empty value disables the preference. */
	if (!sink)
		sink = "Compartido";

	signal(SIGPIPE, SIG_IGN);
	setvbuf(stdout, NULL, _IOFBF, 4096);
	pw_init(&argc, &argv);

	e.want = (struct control) {
		.running = false, .bpm = 100.0, .beats = 4, .subdivision = 0,
		.volume = 0.7, .accent = true, .gen = 0,
	};
	e.ctl = e.want;
	e.pending = e.want;
	e.beat_sub = &SUBDIVISIONS[0];
	e.beat_len = beat_frames(e.ctl.bpm);
	pthread_mutex_init(&e.control_lock, NULL);

	e.main_loop = pw_main_loop_new(NULL);
	if (!e.main_loop) {
		fprintf(stderr, "cannot create the PipeWire main loop\n");
		return 1;
	}
	e.loop = pw_main_loop_get_loop(e.main_loop);
	pw_loop_add_signal(e.loop, SIGINT, on_quit, &e);
	pw_loop_add_signal(e.loop, SIGTERM, on_quit, &e);
	e.event_source = pw_loop_add_event(e.loop, on_events, &e);
	e.timer_source = pw_loop_add_timer(e.loop, on_timer, &e);
	e.stdin_source = pw_loop_add_io(e.loop, STDIN_FILENO,
					SPA_IO_IN | SPA_IO_HUP | SPA_IO_ERR, false, on_stdin, &e);

	/* Realtime scheduling is requested by hand rather than through the
	 * stock client.conf. Its default asks the desktop portal first, and a
	 * portal that lost track of RTKit reports a realtime budget of 0 µs:
	 * module-rt then sets RLIMIT_RTTIME to 0, and the kernel SIGKILLs the
	 * audio thread the first time a scheduler tick catches it running.
	 * Asking RTKit directly, with an explicit budget, avoids that. */
	e.context = pw_context_new(e.loop, pw_properties_new("module.rt", "false", NULL), 0);
	if (!e.context) {
		fprintf(stderr, "cannot create the PipeWire context\n");
		return 1;
	}
	/* A hard RLIMIT_RTTIME below that budget cannot be raised from here,
	 * and a realtime thread under it gets killed: rather keep time at
	 * normal priority. metronome-engine.sh normally avoids this case. */
	struct rlimit rt_limit;
	if (getrlimit(RLIMIT_RTTIME, &rt_limit) == 0 && rt_limit.rlim_max != RLIM_INFINITY &&
	    rt_limit.rlim_max < 200000)
		fprintf(stderr, "realtime budget is %lu us, staying at normal priority\n",
			(unsigned long)rt_limit.rlim_max);
	else if (!pw_context_load_module(e.context, "libpipewire-module-rt",
			"{ rtportal.enabled = false nice.level = -11 "
			"rt.time.soft = 200000 rt.time.hard = 200000 }",
			NULL))
		fprintf(stderr, "realtime scheduling unavailable: %s\n", strerror(errno));
	e.core = pw_context_connect(e.context, NULL, 0);
	if (!e.core) {
		fprintf(stderr, "cannot connect to PipeWire: %s\n", strerror(errno));
		return 1;
	}

	struct pw_properties *props = pw_properties_new(
		PW_KEY_MEDIA_TYPE, "Audio",
		PW_KEY_MEDIA_CATEGORY, "Playback",
		PW_KEY_MEDIA_ROLE, "Production",
		PW_KEY_MEDIA_NAME, "Metronome",
		PW_KEY_APP_NAME, "Metronome",
		PW_KEY_NODE_NAME, "wh01s17-metronome",
		PW_KEY_NODE_DESCRIPTION, "Metronome",
		/* The graph's usual quantum: asking for less would wake every
		 * other audio client more often for no gain in precision, since
		 * pulses are placed by frame inside the buffer anyway. */
		PW_KEY_NODE_LATENCY, "1024/48000",
		NULL);
	if (sink[0] != '\0')
		pw_properties_set(props, PW_KEY_TARGET_OBJECT, sink);

	e.stream = pw_stream_new(e.core, "wh01s17-metronome", props);
	if (!e.stream) {
		fprintf(stderr, "cannot create the PipeWire stream\n");
		return 1;
	}
	pw_stream_add_listener(e.stream, &e.stream_listener, &stream_events, &e);

	uint8_t pod_buf[1024];
	struct spa_pod_builder builder = SPA_POD_BUILDER_INIT(pod_buf, sizeof pod_buf);
	const struct spa_pod *params[1];
	params[0] = spa_format_audio_raw_build(&builder, SPA_PARAM_EnumFormat,
		&SPA_AUDIO_INFO_RAW_INIT(.format = SPA_AUDIO_FORMAT_F32,
					 .channels = 1,
					 .rate = RATE,
					 .position = { SPA_AUDIO_CHANNEL_MONO }));

	if (pw_stream_connect(e.stream, PW_DIRECTION_OUTPUT, PW_ID_ANY,
			      PW_STREAM_FLAG_AUTOCONNECT | PW_STREAM_FLAG_MAP_BUFFERS |
			      PW_STREAM_FLAG_RT_PROCESS,
			      params, 1) < 0) {
		fprintf(stderr, "cannot connect the PipeWire stream\n");
		return 1;
	}

	pw_main_loop_run(e.main_loop);
	e.quitting = true;

	pw_stream_destroy(e.stream);
	pw_core_disconnect(e.core);
	pw_context_destroy(e.context);
	pw_main_loop_destroy(e.main_loop);
	pw_deinit();
	return e.exit_code;
}
