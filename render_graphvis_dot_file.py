#!/usr/bin/env python
#-*-coding: iso8859-1-*-
__author__ = "DEPED"

import string
import requests
import subprocess

# Global variables
graphviz_server_ip = "http://127.0.0.1:8080"
graphviz_server_url = graphviz_server_ip + "/svg"
clean_topology = ""
headers = {
    "cache-control": "no-cache",
    }
# Grab topology info from ALFRED batadv-vis
vis = subprocess.check_output(["/usr/local/sbin/batadv-vis"])
# Slight syntax modification on dot file to graphviz renderer expected syntax
topology = string.replace(vis, "digraph {", "digraph G {")
# Remove hosts from topology
for line in topology.splitlines():
        if "TT" not in line:
                clean_topology += str(line)
# HTTP POST request to graphviz server. Returns SVG binary rendered topology
rendered_topology = requests.request("POST", graphviz_server_url, data=clean_topology, headers=headers)
# Write SVG picture file under Observium HTML site
with open("/opt/observium/html/mesh_topology.svg", "wb") as file_:
    file_.write(rendered_topology.content)
