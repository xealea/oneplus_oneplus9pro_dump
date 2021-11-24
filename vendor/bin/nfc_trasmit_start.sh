#!/system/bin/sh
echo "disable nfc"
echo "nfc transmit start"
pnscr -t 1 -d nq-nci -f /vendor/etc/rf_continue_on.txt
 