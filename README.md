# GMII-Packet-Generator-VHDL
A Packet Generator using VHDL to make Gigabit level traffic

This is a simple packet generator for ethernet traffic which you can use 4 switches on the FPGA IO to control how fast the traffic flows. A lot of this work comes from [hamsterworks](https://github.com/hamsternz/FPGA_GigabitTx), I just modified it to work with a GMII based PHY instead of a RGMII PHY which his board had

This provided UCF in the repository is for the [Genesys FPGA dev board](http://store.digilentinc.com/genesys-virtex-5-fpga-development-board-limited-time-see-genesys2/) so your pin layout will differ if you are using a different dev board.
