# stsignd -- A simple signer

See ./stsignd for a description.

## Installation

Install the binary.

    sudo install stsignd /usr/bin/

Install the user service unit.

	install stsigner.service ~/.config/systemd/user/
    systemctl --user daemon-reload

Enable and start the service.

	systemctl --user enable --now stsigner
