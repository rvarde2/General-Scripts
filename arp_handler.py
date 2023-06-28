#!/usr/bin/python

from scapy.all import *
import threading
import time

killer = False
ip_to_mac={}
ip_to_mac["192.168.1.6"] = "12:34:56:12:34:56"

def PacketHandler_pf0hpf(pkt):
    global ip_to_mac
    if (pkt.haslayer(ARP) and pkt.op==1):
        if(pkt.pdst in ip_to_mac):
            p=ARP(op=2,psrc=pkt.pdst,pdst=pkt.psrc,hwsrc=ip_to_mac[pkt.pdst],hwdst=pkt.hwsrc)
            send(p,iface="pf0hpf")
    return

def pf0hpf_thread():
    global killer
    sniff(iface="pf0hpf",prn=PacketHandler_pf0hpf,stop_filter=killer)

def PacketHandler_p0(pkt):
    global ip_to_mac
    if (pkt.haslayer(ARP) and pkt.op==1):
        if(pkt.pdst in ip_to_mac):
            p=ARP(op=2,psrc=pkt.pdst,pdst=pkt.psrc,hwsrc=ip_to_mac[pkt.pdst],hwdst=pkt.hwsrc)
            send(p,iface="p0")
    return

def p0_thread():
    global killer
    sniff(iface="p0",prn=PacketHandler_p0,stop_filter=killer)

t1 = threading.Thread(target=pf0hpf_thread)
t2 = threading.Thread(target=p0_thread)

t1.start()
t2.start()

try:
    while True:
        time.sleep(100)
except KeyboardInterrupt:
    killer = True

t1.join()
t2.join()

