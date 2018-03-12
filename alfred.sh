#!/bin/bash
# Starting ALFRED in SLAVE mode, allow some time for batman to settle down before starting ALFRED
/bin/sleep 10
/usr/local/sbin/alfred -i bat0 > /dev/null 2>&1
