# OpenWRT Raspi travel-router build script 
## Multi-WAN tethering plus hotel captive portal auth & VPN support.

**This OpenWRT build script & configuration files creates a Raspberry Pi 3, 4 or 5 image supporting:**
 - **Multiple WAN connection options:**
   - Wifi as a WAN client
   - Built-in Ethernet as WAN client
   - iPhone tethering as WAN client
   - Android tethering as WAN client
   - Automatic WAN failover if multiple WAN connections exist
- **Packet TTL fixes to hide device sharing from upstream carriers**
- **The Luci "Travelmate" hotel captive portal GUI add-on** 


# Instructions
### **Step 1.** 

Research and obtain a Linux compatible USB Wifi adapter **with a chipset that supports _"AP mode"_**. 

To confirm that the chipset of your USB wifi adapter is supported in OpenWRT: 

- _Search https://forum.openwrt.org to confirm and obtain the correct package name(s) of the OpenWRT wifi chipset packages required._
- _To learn more about USB wifi adapters with Linux/OpenWRT & AP mode support see here: [https://github.com/morrownr/USB-WiFi](https://github.com/morrownr/USB-WiFi)._

_(Built-in Raspi radio supports AP Mode and will be used for hotel Wifi piggyback, a second USB wifi dongle also supporting AP Mode will be needed to service Wifi clients)._

---

### **Step 2.** 

  -  Download `raspi-travelrouter.sh` script and make it executable: `chmod +x raspi-travelrouter.sh`. 
       
   - Download base-travelrouter-raspi.tar.gz and extract the contents.

---

### **Step 3.** 

Adjust the `ARCH=` & `IMAGE_PROFILE=` sections of `raspi-travelrouter.sh` to suit your Raspi hardware (script default is Raspi 4).
   ```
   ARCH="????"          # Set to ARCH="bcm2710" for Raspi3, ARCH="bcm2711" for Raspi 4, ARCH="bcm2712" for Raspi 5
   IMAGE_PROFILE="???"  # Set to rpi-3, rpi-4 or rpi-5 | For available profiles run $SOURCE_DIR/make info
   ```
---

### **Step 4.** 

On the last line of the `CUSTOM_PACKAGES` section at the top of the `raspi-travelrouter.sh` script, add the USB device driver package names you confirmed in Step 1 above. _(The USB chipset packages included in the default script are examples and can be removed. See script comments for more)._ 

You can add any number of other OpenWRT packages in the `CUSTOM_PACKGES` section to create your own custom travel-router recipe.

---


### **Step 5.** 

**FROM AN x86 LINUX SYSTEM**, run the script and follow the prompts: `./raspi-travelrouter.sh`. You will be prompted for sudo, and then prompted to add custom OpenWRT config files. Copy the _**unzipped**_ contents of `base-travelrouter-raspi.tar.gz` to the (automatically created) path  `$(pwd)/openwrt_inject_files` and hit enter to start the build. 


---

### **Step 6.** 

When the OpenWRT build has completed, several newly built firmwares can be found under `$(pwd)/firmware_images`. 

**SquashFS** will be the best choice for most use cases on Raspi. Flash your choice of image to MMC in your preferred way, insert it into your Raspberry Pi and boot.

---

### **Step 7.** 

After first boot give your Raspi a few minutes to settle before trying to connect to the default "OpentWRT" SSID (no password). 

When connected, browse to http://10.1.10.1 to reach the OpenWRT Luci GUI. Use Luci to add an OpenWRT admin password and **change the SSID name to something stealthy**. 

 - To configure an upstream hotel wifi network as WAN, in Luci look for the **Travelmate** page.
 - If using a tethered phone or direct ethernet for WAN, internet access will automatically be shared by the travel-router's new & stealthy SSID.

---

### **Step 8.** 

Optional. If you wire a power button across gpio_pin3 (Pin5) and any ground pin, adding `dtoverlay=gpio-shutdown,gpio_pin=3` to `/boot/config.txt` enables both power ON and SHUTDOWN functionality.

<p align="center">
  <img src="https://github.com/itiligent/OpenWRT-Raspi-TravelRouter/blob/main/RaspiPwrButton.PNG" alt="Screenshot" width="300">

<p align="center">
Image courtesy https://github.com/Howchoo/pi-power-button
</p>

---
