# Agentless Salt for Windows

This code is forked from https://github.com/saltstack/saltwinshell.
## About

The Agentless Windows Module can run any Salt SSH command on a target Windows server or desktop, such as the following:

```
salt-ssh testwin disk.usage
```

## Requirements

### Target Windows systems

- English version of Windows
- Windows versions:
  - Windows 7
  - Windows 8.1
  - Windows 10
  - Windows Server 2008 R2
  - Windows Server 2012 R2
  - Windows Server 2016
- Powershell 3.0 or later
- OpenSSH
- A key for the admin user


### Salt master

- The `/etc/salt/roster` file must have a configuration section for every Windows machine you want to connect to. The configuration must have a local admin user, as in the following example. Note that the private key defaults to /etc/salt/pki/master/ssh/salt-ssh.id_ed25519

```yaml
win2012dev: # Minion ID
  host: <IP address or hostname>
  user: <local Windows admin username>
  priv: <path to private key for ssh>
  winrm: True
```

> **NOTE:** Domain credentials are not supported.


## Installation instructions
clone, build, and install from https://gitlab.rentec.com/infrastructure-as-code/salt/saltwinshell

Install on your working Salt Master:

```
python3 setup.py build
pyton3 setup.py install
```


```
salt-ssh <minion id> test.ping
```

The first time you run `salt-ssh` against a Windows minion it will take a bit
longer than usual since it has to deploy a working Salt python environment.
Subsequent runs should be much faster.

The shell libraries for agentless Windows to work via `salt-ssh`, installing
this library activates the ability to hit windows targets.

## Release process

- Create a new branch:

```
git checkout -b <new branch name>
```

- Make updates.
- Create a tag:

```
git tag -a v2018.3 -m "Version v2018.3 release" -s
git push origin 2018.3
git push --tags
```

- Copy in your python environment zip files to the root. Make sure they match
what the setup.py is expecting.
- Run the following:

  ```
  python setup.py bdist_wheel
  ```

  The file you want will be found in the `dist` directory and will look something  like:

  ```
  saltwinshell-2017.7-cp27-cp27mu-linux_x86_64.whl
  ```

- Copy to the pypi state for distribution
