# High performance wireless mesh networks
## Combining inexpensive hardware (OpenWRT supported access points) with enterprise grade Ubiquiti airMAX equipment

This project aims to establish a medium scale (kilometer size) wireless mesh network capable of serving robust internet to video streaming clients. In order to maximize overall available bitrate to clients while keeping costs low, we propose to combine non-mesh enterprise grade equipment from Ubiquiti with inexpensive access-points capable of running OpenWRT linux.

The backbone nodes will provide:
```
High speed connectivity to selected access-points with a point to multipoint  topology (PtMP)
VLAN based traffic isolation between mesh and management traffic
Will be "invisible" to mesh traffic
```

The access points will provide:
```
Entrypoints to non-mesh clients such as cell phones, WiFi video streaming devices, etc.
Seamless roaming to these non-mesh clients. They will be able to roam freely between access-points.
Mesh routing to clients, traffic will be steered to the internet through a dynamically calculated highest throughput path
```

One or more gateway nodes will provide:
```
Internet connectivity to non-mesh clients
Smart queue management to reduce bufferbloat, minimizing response time to video services
Adblocking to improve overall traffic efficiency
Resilience through multiple gateways
```



![Self-editing Diagram](https://github.com/AlverGant/mesh_2.0/blob/master/mesh2.0.svg)

<a href="https://www.draw.io/?lightbox=1&highlight=0000ff&edit=_blank&layers=1&nav=1&title=Mesh%202.0#Uhttps%3A%2F%2Fraw.githubusercontent.com%2FAlverGant%2Fmesh_2.0%2Fmaster%2FMesh%25202.0" target="_blank">edit_mesh_diagram.svg</a> is an SVG file with embedded PNG data. (Click on the link, not the image to enable editing.)
