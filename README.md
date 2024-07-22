# pyenv

pipx install python-lsp-server

pipx inject python-lsp-server flake8

pipx install black

pipx install isort

pipx install pylint

pipx inject pylint pylint-venv

configure pilntrc:
https://github.com/jgosmann/pylint-venv

# new 
sudo pacman -S pyenv

sudo pacman -S python-pipx

pyenv install PYTHON_VERSION

~/.pyenv/versions/PYTHON_VERSION/bin/python -m venv ~/.pyenv/versions/PYTHON_VERSION/envs/ENV_NAME

export PIPX_DEFAULT_PYTHON=~/.pyenv/versions/PYTHON_VERSION/bin/python

pipx install poetry

source ~/.pyenv/versions/PYTHON_VERSION/envs/ENV_NAME/bin/activate

poetry install --no-root

# poetry

pipx install poetry==1.5.2 --suffix '@1.5.2'

poetry@1.5.2 install
