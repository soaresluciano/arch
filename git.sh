echo -n "Please enter your name: "
read name
git config --global user.name "$name"

echo -n "Please enter your e-mail: "
read email
git config --global user.email "$email"

git config --global core.editor "vim"

echo -n "Which type of key do you want to generate? (ed25519/rsa) "
read keytype

if [ "$keytype" == "ed25519" ]; then
  ssh-keygen -t ed25519 -C $email
elif [ "$keytype" == "rsa" ]; then
  ssh-keygen -t rsa -b 4096 -C $email
else
  echo "Invalid key type. Please enter 'ed25519' or 'rsa'."
  exit 1
fi

exec ssh-agent bash
ssh-add ~/.ssh/id_$keytype

cat ~/.ssh/id_$keytype.pub

