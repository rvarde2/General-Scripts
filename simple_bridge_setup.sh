#! /bin/bash

# Author: Rohan Vardekar
# Script to Setup Namespace Environment and Modify Various Networking Parameters

if [ "$#" -ne 1 ] ; then
    printf "$0: exactly 1 arguments expected\n"
    printf "Usage: ./simple_bridge_setup.sh <command>\n"
    printf "Commands:\n"
    printf "\t-h: help\n"
    printf "\t-c: create setup\n"
    printf "\t-d: delete setup\n"
    printf "\t-t: get terminals\n"
    printf "\t-irate: set interface transmission rate\n"
    printf "\t-idelay: set interface delay\n"
    printf "\t-ijitter: set interface jitter\n"
    printf "\t-iloss: set interface packet loss\n"
    printf "\t-icorrupt: set interface packet corruption\n"
    printf "\t-iduplicate: set interface packet duplication\n"
    printf "\t-ireorder: set interface packet reordering\n"
    printf "\t-ishow: show interface parameters\n"
    printf "\t-ireset: reset interface parameters\n"
    exit 1
fi

if [ $1 == "-c" ] ; then
    #Creating Network Namespace
    sudo ip netns add h1
    sudo ip netns add h2

    #Create Virtual Switch
    sudo ip link add name s1 type bridge

    #Creating Virtual Interfaces
    sudo ip link add h1-eth0 type veth peer name s1-eth1
    sudo ip link add h2-eth0 type veth peer name s1-eth2

    #Assigning Virtual Interface to the Network Namespace
    sudo ip link set h1-eth0 netns h1 
    sudo ip link set h2-eth0 netns h2

    #Attaching Peer Interfaces to the Virtual Switch
    sudo ip link set s1-eth1 master s1
    sudo ip link set s1-eth2 master s1

    #Activate the Peer Interfaces
    sudo ip link set s1-eth1 up
    sudo ip link set s1-eth2 up

    #Turn Up the Virtual Interfaces in Respective Network Namespace
    sudo ip netns exec h1 ip link set dev h1-eth0 up
    sudo ip netns exec h2 ip link set dev h2-eth0 up

    #Assign IP to the  Virtual Interfaces
    sudo ip netns exec h1 ip address add 192.168.1.2/24 dev h1-eth0
    sudo ip netns exec h2 ip address add 192.168.1.3/24 dev h2-eth0

    #Turn On the Virtual Switch
    sudo ip link set s1 up

    #Give IP to Virtual Switch
    sudo ip address add 192.168.1.1/24 brd + dev s1
    
elif [ $1 == "-d" ] ; then
    #Deleting Network Namespaces
    sudo ip netns del h1
    sudo ip netns del h2

    #Deleting Virtual Switch
    sudo ip link delete name s1 type bridge

elif [ $1 == "-t" ] ; then
    #spawn terminals in various namespace with namespace names
    sudo xterm -xrm 'XTerm.vt100.allowTitleOps: false' -T "root" &
    sudo ip netns exec h1 xterm -xrm 'XTerm.vt100.allowTitleOps: false' -T "h1" &
    sudo ip netns exec h2 xterm -xrm 'XTerm.vt100.allowTitleOps: false' -T "h2" &

elif [ $1 == "-irate" ] ; then
    printf "Provide the transmitting interface:"
    read interface
    interface_check=$(ip addr | grep $interface | wc -l)
    if [ $interface_check == "0" ] ; then
        printf "Exiting, Requested Interface Not Found\n"
        exit 1
    fi
    #capturing CPU frequency for bucket size calculation
    freq=$(egrep '^CONFIG_HZ_[0-9]+' /boot/config-$(uname -r) | awk '{split($0,arr,"_"); print arr[3]}' |  awk '{split($0,arr,"="); print arr[1]}')
    printf "Provide the bitrate:"
    read bitrate
    bucket_size_bits=$((bitrate/freq))
    bucket_size_bytes=$((bucket_size_bits/8))
    queue_size=$((bucket_size_bytes*3))
    #check if this is first rule
    first_rule_check=$(sudo tc qdisc show dev $interface | grep -E "fq_codel|noqueue" | wc -l )
    if [ $first_rule_check == "1" ] ; then
        #this is a first rule
        sudo tc qdisc add dev $interface root handle 1: tbf rate $bitrate burst $bucket_size_bytes limit $queue_size
        exit 0
    else
        rule_number=$(sudo tc qdisc show dev $interface | wc -l )
        sudo tc qdisc add dev $interface parent 1: handle $((rule_number+1)): tbf rate $bitrate burst $bucket_size_bytes limit $queue_size
    fi

elif [ $1 == "-idelay" ] ; then
    printf "Provide the transmitting interface:"
    read interface
    interface_check=$(ip addr | grep $interface | wc -l)
    if [ $interface_check == "0" ] ; then
        printf "Exiting, Requested Interface Not Found\n"
        exit 1
    fi
    printf "Provide the delay (e.g. 5ms):"
    read delay_value
    #check if this is first rule
    first_rule_check=$(sudo tc qdisc show dev $interface | grep -E "fq_codel|noqueue" | wc -l )
    if [ $first_rule_check == "1" ] ; then
        #this is a first rule
        sudo tc qdisc add dev $interface root handle 1: netem delay $delay_value
        exit 0
    else
        rule_number=$(sudo tc qdisc show dev $interface | wc -l )
        sudo tc qdisc add dev $interface parent 1: handle $((rule_number+1)): netem delay $delay_value
    fi

elif [ $1 == "-ijitter" ] ; then
    printf "Provide the transmitting interface:"
    read interface
    interface_check=$(ip addr | grep $interface | wc -l)
    if [ $interface_check == "0" ] ; then
        printf "Exiting, Requested Interface Not Found\n"
        exit 1
    fi
    printf "Provide the average delay (e.g. 5ms):"
    read avg_delay_value
    printf "Provide the random variation boundry (e.g. 1ms):"
    read variation_boundry

    #check if this is first rule
    first_rule_check=$(sudo tc qdisc show dev $interface | grep -E "fq_codel|noqueue" | wc -l )
    if [ $first_rule_check == "1" ] ; then
        #this is a first rule
        sudo tc qdisc add dev $interface root handle 1: netem delay $delay_value $variation_boundry
        exit 0
    else
        rule_number=$(sudo tc qdisc show dev $interface | wc -l )
        sudo tc qdisc add dev $interface parent 1: handle $((rule_number+1)): netem delay $delay_value $variation_boundry
    fi

elif [ $1 == "-iloss" ] ; then
    printf "Provide the transmitting interface:"
    read interface
    interface_check=$(ip addr | grep $interface | wc -l)
    if [ $interface_check == "0" ] ; then
        printf "Exiting, Requested Interface Not Found\n"
        exit 1
    fi
    printf "Provide the percent packet loss (e.g. 10):"
    read loss_value
    #check if this is a first rule
    first_rule_check=$(sudo tc qdisc show dev $interface | grep -E "fq_codel|noqueue" | wc -l )
    if [ $first_rule_check == "1" ] ; then
        #this is a first rule
        sudo tc qdisc add dev $interface root handle 1: netem loss $loss_value%
        exit 0
    else
        rule_number=$(sudo tc qdisc show dev $interface | wc -l )
        sudo tc qdisc add dev $interface parent 1: handle $((rule_number+1)): netem loss $loss_value%
    fi

elif [ $1 == "-icorrupt" ] ; then
    printf "Provide the transmitting interface:"
    read interface
    interface_check=$(ip addr | grep $interface | wc -l)
    if [ $interface_check == "0" ] ; then
        printf "Exiting, Requested Interface Not Found\n"
        exit 1
    fi
    printf "Provide the percent packet corruption (e.g. 0.01):"
    read corrupt_value
    #check if this is a first rule
    first_rule_check=$(sudo tc qdisc show dev $interface | grep -E "fq_codel|noqueue" | wc -l )
    if [ $first_rule_check == "1" ] ; then
        #this is a first rule
        sudo tc qdisc add dev $interface root handle 1: netem corrupt $corrupt_value%
        exit 0
    else
        rule_number=$(sudo tc qdisc show dev $interface | wc -l )
        sudo tc qdisc add dev $interface parent 1: handle $((rule_number+1)): netem corrupt $corrupt_value%
    fi

elif [ $1 == "-iduplicate" ] ; then
    printf "Provide the transmitting interface:"
    read interface
    interface_check=$(ip addr | grep $interface | wc -l)
    if [ $interface_check == "0" ] ; then
        printf "Exiting, Requested Interface Not Found\n"
        exit 1
    fi
    printf "Provide the percent packet duplication (e.g. 25):"
    read duplicate_value
    #check if this is a first rule
    first_rule_check=$(sudo tc qdisc show dev $interface | grep -E "fq_codel|noqueue" | wc -l )
    if [ $first_rule_check == "1" ] ; then
        #this is a first rule
        sudo tc qdisc add dev $interface root handle 1: netem duplicate $duplicate_value%
        exit 0
    else
        rule_number=$(sudo tc qdisc show dev $interface | wc -l )
        sudo tc qdisc add dev $interface parent 1: handle $((rule_number+1)): netem duplicate $duplicate_value%
    fi

elif [ $1 == "-ireorder" ] ; then
    printf "Provide the transmitting interface:"
    read interface
    interface_check=$(ip addr | grep $interface | wc -l)
    if [ $interface_check == "0" ] ; then
        printf "Exiting, Requested Interface Not Found\n"
        exit 1
    fi
    printf "Provide the percent packets to be sent immidiately (e.g. 25):"
    read immidiate_packets
    printf "Provide the percent packets to be delayed (e.g. 75):"
    read delayed_packets

    #check if this is a first rule
    first_rule_check=$(sudo tc qdisc show dev $interface | grep -E "fq_codel|noqueue" | wc -l )
    if [ $first_rule_check == "1" ] ; then
        #this is a first rule
        sudo tc qdisc add dev $interface root handle 1: netem reorder $immidiate_packets% $delayed_packets%
        exit 0
    else
        rule_number=$(sudo tc qdisc show dev $interface | wc -l )
        sudo tc qdisc add dev $interface parent 1: handle $((rule_number+1)): netem reorder $immidiate_packets% $delayed_packets%
    fi

elif [ $1 == "-ishow" ] ; then
    printf "Provide the transmitting interface:"
    read interface
    interface_check=$(ip addr | grep $interface | wc -l)
    if [ $interface_check == "0" ] ; then
        printf "Exiting, Requested Interface Not Found\n"
        exit 1
    fi
    sudo tc qdisc show dev $interface 

elif [ $1 == "-ireset" ] ; then
    printf "Provide the transmitting interface:"
    read interface
    interface_check=$(ip addr | grep $interface | wc -l)
    if [ $interface_check == "0" ] ; then
        printf "Exiting, Requested Interface Not Found\n"
        exit 1
    fi
    sudo tc qdisc del dev $interface root

else
        printf "Usage: ./simple_bridge_setup.sh <command>\n"
        printf "Commands:\n"
        printf "\t-h: help\n"
        printf "\t-c: create setup\n"
        printf "\t-d: delete setup\n"
        printf "\t-t: get terminals\n"
        printf "\t-irate: set interface transmission rate\n"
        printf "\t-idelay: set interface delay\n"
        printf "\t-ijitter: set interface jitter\n"
        printf "\t-iloss: set interface packet loss\n"
        printf "\t-icorrupt: set interface packet corruption\n"
        printf "\t-iduplicate: set interface packet duplication\n"
        printf "\t-ireorder: set interface packet reordering\n"
        printf "\t-ishow: show interface parameters\n"
        printf "\t-ireset: reset interface parameters\n"
fi



