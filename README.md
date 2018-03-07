# High performance wireless mesh networks
## Combining inexpensive hardware (OpenWRT supported access points) with enterprise grade Ubiquiti airMAX equipment

Mikrotik NAND flash devices can grow their bad block tables over time.
When burning an OpenWRT image directly onto flash and, particularly if a micro SD card is inserted during the flashing operation, lots of false bad blocks do develop, eventually reaching a high percentage of the storage, rendering the device unusable, incapable even of returning it to RouterOS. It is somewhat unclear to me why this happens but the answer may lie in the electronics, maybe there is a timing issue on the bus which the CPU talks to the flash, that bus is shared with the SD card.

If that's your case like it was mine, here are the instructions to repair it.

First you will need:
```
a TFTP and DHCP server with a network cable connected to ETH1/POE on RouterBoard
a serial console access to the Mikrotik device
a (supplied) OpenWRT ELF modified image capable of wiping out BBT (bad block table)
```

![Self-editing Diagram](https://github.com/AlverGant/mesh_2.0/blob/master/mesh_diagram.svg)

<a href="https://www.draw.io/?lightbox=1&highlight=0000ff&edit=_blank&layers=1&nav=1&title=Mesh%202.0#Uhttps%3A%2F%2Fraw.githubusercontent.com%2FAlverGant%2Fmesh_2.0%2Fmaster%2FMesh%25202.0" target="_blank">edit_mesh_diagram.svg</a> is an SVG file with embedded PNG data. (Click on the link, not the image to enable editing.)
