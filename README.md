## OpenWRT Raspi travel router build script with multi-WAN (Wifi, Ethernet, Android & iPhone piggyback options), captive portal authentication & VPN support.

**This OpenWRT image build script & supplied configuration files will produce a Raspberry Pi 3 or 4 travelrouter flash image supporting:**
 - **Multiple WAN connection options:**
   - Wifi as WAN client
   - Built-in Ethernet as WAN
   - iPhone tethered WAN
   - Android tethered WAN
   - Automatic WAN failover if multiple WAN connections exist. (Load balancing is also possible but not default).
- **Packet TTL fixes to stealth downstream shared devices (useful for carrier plans that throttle if tethering is detected)**
- **The "Travelmate" package for captive portal piggyback support, wifi client settings GUI management and VPN termination.** 

## Instructions

### Before You Begin

**1.** Research and obtain a Linux compatible USB Wifi adapter with a chipset that supports **AP mode**. _(1st radio is for Wifi piggyback, 2nd radio is for all your Wifi clients)._

**2.** Next confirm that the chipset of your USB wifi adapter is supported in OpenWRT: 
- _To learn more about USB wifi adapters with Linux/OpenWRT & AP mode support here is a great resource: [https://github.com/morrownr/USB-WiFi](https://github.com/morrownr/USB-WiFi)._
- _Search https://forum.openwrt.org/ to confirm and obtain the name(s) of the OpenWRT Wifi chipset driver package(s) required._

### Starting the Build

**3.** Download the raspi-travelrouter.sh script and make it executable: `chmod +x raspi-travelrouter.sh`

**4.** Adjust the `ARCH=` & `IMAGE_PROFILE=` sections to suit your Raspi hardware (default is to build for Raspi 4).
   ```
    ARCH="???"           # Set to ARCH="bcm2710" for Raspi3 or ARCH="bcm2711" for Raspi4 
    IMAGE_PROFILE="???"  # Set to IMAGE_PROFILE="rpi-3" or IMAGE_PROFILE="rpi-4"
   ``` 
**5.** On the last line of the CUSTOM_PACKAGES section of the script, add the USB device driver package names that you confirmed in the steps above. _(The USB adapter drivers inlcuded in the default script are only examples and can be removed. See script comments for more)._ You can of course add any number of extra OpenWRT packages in this section to create your very own recipe.

**6.** Run the script as sudo and follow the prompts: `sudo ./raspi-travelrouter.sh`

**7.** When prompted to add custom OpenWRT config files, copy the unzipped contents of base-travelrouter-raspi.tar.gz to  `$(pwd)/openwrt_inject_files` and hit enter to start the build. 

**8.** When the build has completed, newly built firmwares for a range of install options can be found under `$(pwd)/firmware_images`. SquashFS will be the best choice for most applications.

**9.** Flash the new image to MMC in the usual way, insert it into your Raspberry Pi, then boot.

**10.** After first boot (give it some time), connect to the default "OpentWRT" SSID (no password) and browse to http://10.1.10.1. You may then add a Raspi admin password and setup the SSID & upstream network connections through the Luci gui. Upstream wifi network piggybacking should be configured through the Travelmate page, whereas tethered phones or direct ethernet WAN links will automatically connect and share with your new SSID.

**11.** Optional. If you wire a power button across gpio_pin3 (Pin5) and any ground pin, adding `dtoverlay=gpio-shutdown,gpio_pin=3` to the /boot/config.txt file enables both power ON and SHUTDOWN functionality.

<p align="center">
  <img src="https://github.com/itiligent/OpenWRT-Raspi-TravelRouter/blob/main/RaspiPwrButton.PNG" alt="Screenshot" width="300">
</p>
Image courtesy https://github.com/Howchoo/pi-power-button

