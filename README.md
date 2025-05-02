# Olenellus

A simple Bash script to automate the creation of a new sudo user, set up SSH key authentication, and harden SSH configuration on a Debian/Ubuntu server.

## Usage

```sh
sudo ./olenellus.sh <new_username> [ssh_port]
```

- `<new_username>`: The username for the new user to create.
- `[ssh_port]`: (Optional) The SSH port to use (default: 111).

## What it does

- Updates system packages
- Creates a new user and adds them to the sudo group
- Sets up SSH key authentication for the new user (copies root's authorized_keys if present)
- Hardens SSH configuration (disables root login and password authentication, sets custom port)
- Restarts the SSH daemon

## Final steps

After running the script, follow the printed instructions to add your SSH key and connect to the server securely.

## License

MIT
