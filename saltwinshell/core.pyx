# -*- coding: utf-8 -*-
'''
Core functions to impliment the salt windows shell
'''
# Copyright 2021 VMware, Inc.
# SPDX-License-Identifier: Apache-2.0
from __future__ import absolute_import

import os
import logging
import salt.exceptions
import paramiko
import pathlib
import scp
import tempfile

try:
    import salt.utils.stringutils as stringutils
except ImportError:
    # This exception handling can be removed once 2017.7 is no longer
    # supported.
    import salt.utils as stringutils
#from connection import Connection
from salt.client.ssh.shell import Shell as LinuxShell
import ntpath
from saltwinshell.version import version as version

log = logging.getLogger(__name__)

# Windows Powershell Shim - actually, this is python
SSH_PS_SHIM =  \
        '\n'.join(
            [s.strip() for s in r'''
import base64

exec(base64.b64decode("""{SSH_PY_CODE}"""))
'''.split('\n')])


def set_winvars(self, ssh_python_env=None):
    '''
    Set the Win Vars
    '''
    self.thin_dir = 'c:/saltremote/thin'
    self.python_dir = 'c:/saltremote/bin'
    pyver = 'Py3'
    self.python_env_map = {
            'AMD64': 'Salt-Env-{0}-AMD64-{1}.zip'.format(version, pyver),
            'x86'  : 'Salt-Env-{0}-x86-{1}.zip'.format(version, pyver),
            }
    self.python_saltwinshell = '/extra/salt/saltwinshell'


def gen_shim(py_code_enc):
    '''
    Generate a PowerShell shim
    '''
    cmd = SSH_PS_SHIM.format(SSH_PY_CODE=py_code_enc)
    return cmd


def get_target_shim_file(self, target_shim_file):
    '''
    Get the target shim file
    '''
    return ntpath.normpath(ntpath.sep.join((self.python_dir, target_shim_file)))


def call_python(self, target_shim_file):
    '''
    Call python stuff
    '''
    return self.shell.exec_cmd('{0} {1}'.format(ntpath.normpath(ntpath.sep.join((self.python_dir, 'python.exe'))), ntpath.normpath(target_shim_file)))


def deploy_python(self):
    '''
    Deploy the Windows python environment
    '''
    if not self.python_env:
        log.debug('No Python Environment found. Determining which env to use')
        self.python_env = os.path.join(self.python_saltwinshell, self.python_env_map[self.arch])
        if not os.path.isfile(self.python_env):
            if os.path.isfile(os.path.join(self.python_saltwinshell, self.python_env_map[self.arch])):
                self.python_env = os.path.join(self.python_saltwinshell, self.python_env_map[self.arch])
        if not os.path.isfile(self.python_env):
            raise salt.exceptions.SaltConfigurationError( 'Python env: {0} doesn\'t exist.'.format(self.python_env))
    self.shell.send(
        self.python_env,
        os.path.join(self.python_dir, 'bin.zip'),
        makedirs=True,
    )

    stdout, stderr, retcode = self.shell.exec_cmd("""powershell "Expand-Archive -Path '{0}' -DestinationPath '{1}'""".format( os.path.join(self.python_dir, 'bin.zip'), self.python_dir))
    log.trace('shim_cmd {0} - {1} - {2}'.format(stdout, stderr, retcode))
    return True


class Shell(LinuxShell):
    def send(self, local, remote, makedirs=False):
        '''
        send a file to a remote system using smb
        '''
        conn = Connection(self.host, self.user, self.priv)
        ret_stdout = ret_stderr = retcode = None
        if makedirs:
            log.debug('Making directory {0} on {1}'.format(ntpath.dirname(ntpath.normpath(remote)),self.host ))
            ret = conn.cmd_exec('mkdir {0}'.format(ntpath.dirname(ntpath.normpath(remote))))
            log.trace('{0} - {1} - {2}'.format(ret[0], ret[1], ret[2]))

        log.debug('Copying {0} to {1} on minion with makedirs {2}'.format(local, remote, makedirs))
        ret = conn.send(local, remote)

        if not ret:
            ret_stderr = "Failed to send file"
            retcode = 1
        else:
            retcode = ret[2]
            ret_stdout = ret[0]
            ret_stderr = ret[1]
            log.trace('COPY {0} - {1} - {2}'.format(ret[0], ret[1], ret[2]))

        return ret_stdout, ret_stderr, retcode



    def exec_cmd(self, cmd):
        '''
        Execute a remote command
        '''
        logmsg = 'Executing command: {0}'.format(cmd)
        if 'decode("base64")' in logmsg or 'base64.b64decode(' in logmsg:
            log.debug('Executed SHIM command. Command logged to TRACE')
            log.trace(logmsg)
        else:
            log.debug(logmsg)

        conn = Connection(self.host, self.user)
        ret, err, code = conn.cmd_exec(cmd)
        log.trace("COMMAND: cmd:{0} - ret:{1} - err:{2} - code:{3}".format(cmd, ret, err, code))
        return ret, err, code




class Connection:
    def __init__(self, host, user, key='/etc/salt/pki/master/ssh/salt-ssh.id_ed25519'):
        self.host = host
        self.user = user
        self.key = key
        self.conn = paramiko.client.SSHClient()
        self.conn.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        self.connected = False
        if False == os.path.isfile(self.key):
            raise salt.exceptions.SaltConfigurationError( 'ssh config error: {0} doesn\'t exist.'.format(self.key))
        if False == os.access(self.key, os.R_OK):
            raise salt.exceptions.SaltConfigurationError( 'cannot access: {0}'.format(self.key))

    def connect(self, host=None, user=None):
        if host:
            self.host = host
        if user:
            self.user = user
        try:
            self.conn.connect(self.host, username=self.user, key_filename=self.key)
            self.connected = True
        except:
            pass

        return self.connected


    def connect_scp(self):
        scp_client = None
        if not self.connected:
            con = self.connect()

        if self.connected:
            scp_client = scp.SCPClient(self.conn.get_transport())

        return scp_client


    def send(self, local, remote):
        err = None
        stdout = None
        code = None
       
        try:
            scp_c = self.connect_scp()
            if scp_c:
                scp_c.put(local, remote.replace("c:", "").replace("\\", "/"))
                scp_c.close()
                code = 0
            else:
                stdout = "Failed to open SCP"
                err = "SCP connection failed"
                code = 1
        except Exception as e:
            stdout = "Failed to upload file {0}".format(remote.replace("c:","").replace("\\","/"))
            err = e
            code = 1

        return stdout, err, code

    def cmd_exec(self, cmd):
        ret = None
        err = None
        code = None

        if not self.connected:
            self.connect()

        if self.connected:
            try:
                stdin, stdout, stderr  = self.conn.exec_command(cmd)
                ret = stdout.read().decode()
                err = stderr.read().decode()
                code = 0
                # return codes for signallign
                # I don't yet have a way to harvest the return codes from scripts run via ssh
                if 'deploy' in ret:
                    code = 11
                elif 'ext_mods' in ret:
                    code = 13
                elif 'exists but is not a directory' in err:
                    code = 73
                if err and 'WARNING' not in err:
                    code = 1	                
            except:
                code = 1

        else:
            ret = ""
            err = "Unable to connect to {}".format(self.host)
            code = 1

        return ret, err, code

