# Pi-Hole Activity Monitor
# Written by Atanas Malinov 1/1/2022

#!/bin/bash

# Exports pin 22 and pin 27  to userspace
echo "22" > /sys/class/gpio/export
echo "27" > /sys/class/gpio/export

# Sets pin 22 and pin 27 as an output
echo "out" > /sys/class/gpio/gpio22/direction
echo "out" > /sys/class/gpio/gpio27/direction

# Assign names for LED output pins
green_led="22"
red_led="27"

# Test both leds
     echo "1" > /sys/class/gpio/gpio${green_led}/value
     echo "1" > /sys/class/gpio/gpio${red_led}/value
     sleep 2
     echo "0" > /sys/class/gpio/gpio${green_led}/value
     echo "0" > /sys/class/gpio/gpio${red_led}/value
     sleep 1

# Monitor pi-hole activity thru pihole.log
tail -F -n1 /var/log/pihole.log | while read input
do
 case $input in
   *" blacklisted "* |  *" blocked "* )
     echo "1" > /sys/class/gpio/gpio${red_led}/value
     sleep 0.1
     echo "0" > /sys/class/gpio/gpio${red_led}/value
     sleep 0.01
 ;;
   *" reply "* | *" cached "*)
     echo "1" > /sys/class/gpio/gpio${green_led}/value
     sleep 0.1
     echo "0" > /sys/class/gpio/gpio${green_led}/value
     sleep 0.01
 ;;
   *" query"*)     # can include and *" forwarded "* 
     echo "1" > /sys/class/gpio/gpio${green_led}/value
     echo "1" > /sys/class/gpio/gpio${red_led}/value
     sleep 0.1
     echo "0" > /sys/class/gpio/gpio${green_led}/value
     echo "0" > /sys/class/gpio/gpio${red_led}/value
     sleep 0.01
 esac
done
