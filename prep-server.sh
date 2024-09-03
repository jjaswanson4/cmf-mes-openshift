#a small script to ensure
python3.11 -m pip install --upgrade pip
pip install -r requirements/requirements.txt
ssh-keygen -q -t rsa -N '' -f ~/.ssh/id_rsa <<< y
ssh-copy-id ansible@192.168.1.50