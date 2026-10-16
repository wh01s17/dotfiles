# Set identification from install inputs
if [[ -n ${WH01S17_USER_NAME//[[:space:]]/} ]]; then
  git config --global user.name "$WH01S17_USER_NAME"
fi

if [[ -n ${WH01S17_USER_EMAIL//[[:space:]]/} ]]; then
  git config --global user.email "$WH01S17_USER_EMAIL"
fi
