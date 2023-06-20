#! /bin/bash

if [ "$#" -ne 1 ] ; then
    printf "$0: exactly 1 arguments expected\n"
    printf "Usage: ./simple_setup.sh <command>\n"
    printf "Commands:\n"
    printf "\t-h: help\n"
    printf "\t-c: create setup\n"
    printf "\t-d: delete setup\n"
    printf "\t-t: get terminals\n"
    printf "\t-show: show ovs configuration\n"
    printf "\t-bridges: list ovs bridges\n"
    printf "\t-ports: list ports on specific ovs bridge\n"
    printf "\t-get_fail_mode: get current fail mode\n"
    printf "\t-set_fail_mode: what to do if could not reach to controller\n"
    printf "\t-show_ft: dump the flow table\n"
    printf "\t-add_ft: add flow table entry\n"
    printf "\t-del_ft: delete all flow table entries\n"
    printf "\t-mac_addresses: dump the learned mac addresses\n"

    exit 1
fi

if [ $1 == "-c" ] ; then
    #Creating Network Namespace
    sudo ip netns add h1
    sudo ip netns add h2

    #Create Virtual Switch
    sudo ovs-vsctl add-br s1

    #Creating Virtual Interfaces
    sudo ip link add h1-eth0 type veth peer name s1-eth1
    sudo ip link add h2-eth0 type veth peer name s1-eth2

    #Assigning Virtual Interface to the Network Namespace
    sudo ip link set h1-eth0 netns h1 
    sudo ip link set h2-eth0 netns h2

    #Attaching Peer Interfaces to the Virtual Switch
    sudo ovs-vsctl add-port s1 s1-eth1
    sudo ovs-vsctl add-port s1 s1-eth2

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
    sudo ip address add 192.168.1.1/24 dev s1
    
elif [ $1 == "-d" ] ; then
    #Deleting Network Namespaces
    sudo ip netns del h1
    sudo ip netns del h2

    #Deleting Virtual Switch
    sudo ovs-vsctl del-br s1

elif [ $1 == "-t" ] ; then
    sudo xterm -xrm 'XTerm.vt100.allowTitleOps: false' -T "root" &
    sudo ip netns exec h1 xterm -xrm 'XTerm.vt100.allowTitleOps: false' -T "h1" &
    sudo ip netns exec h2 xterm -xrm 'XTerm.vt100.allowTitleOps: false' -T "h2" &

elif [ $1 == "-show" ] ; then
    sudo ovs-vsctl show

elif [ $1 == "-bridges" ] ; then
    sudo ovs-vsctl list-br

elif [ $1 == "-ports" ] ; then
    printf "name of the ovs bridge:"
    read bridge_name  
    sudo ovs-vsctl list-ports $bridge_name | while read portname; do portnumber=$(sudo ovs-vsctl get Interface $portname ofport);echo "$portnumber:$portname";done

elif [ $1 == "-get_fail_mode" ] ; then
    printf "name of the ovs bridge:"
    read bridge_name  
    sudo ovs-vsctl get-fail-mode $bridge_name

elif [ $1 == "-set_fail_mode" ] ; then
    printf "name of the ovs bridge:"
    read bridge_name  
    printf "mode(standalone:act as switch, secure:drop):"
    read mode  
    sudo ovs-vsctl set-fail-mode $bridge_name $mode

elif [ $1 == "-show_ft" ] ; then
    printf "name of the ovs bridge:"
    read bridge_name  
    sudo ovs-ofctl dump-flows $bridge_name

elif [ $1 == "-add_ft" ] ; then
    printf "name of the ovs bridge:"
    read bridge_name  
    command="sudo ovs-ofctl add-flow $bridge_name "
    printf "Choose the Rule:\n"
    printf "1. Simple Switch\n"
    printf "2. ARP Forwarding\n"
    printf "3. Specific TCP Rule\n"
    printf "Choice:"
    read choice
    
    if [ "$choice" ==  "1" ] ; then
        command=$command"action=normal "
    elif [ "$choice" ==  "2" ] ; then
        command=$command"arp,action=normal"
    elif [ "$choice" ==  "3" ] ; then
        printf "Choose Type of Forwarding Rule:\n"
        printf "1.L1 Forwarding: Based on the Ports\n"
        printf "2.L2 Forwarding: Based on the MAC Addresses\n"
        printf "3.L3 Forwarding: Based on the IP\n"
        printf "4.L4 Forwarding: Based on the TCP Port\n"
        printf "Forwarding Choice:"
        read forwarding_choice

        if [ "$forwarding_choice" ==  "1" ] ; then
             printf "Incoming Port:"
             read in_port
             command=$command"in_port=$in_port"        
        elif [ "$forwarding_choice" ==  "2" ] ; then
             printf "Destination MAC Address:"
             read dest_mac
             command=$command"dl_dst=$dest_mac"
        elif [ "$forwarding_choice" ==  "3" ] ; then
             printf "Is it based on source or destination:"
             read s_d
             if [ "$s_d" ==  "source" ] ; then
                printf "Source IP:"
                read src_ip
                command=$command"ip,nw_src=$src_ip"
             elif [ "$s_d" ==  "destination" ] ; then
                printf "Destination IP:"
                read dest_ip
                command=$command"ip,nw_dst=$dest_ip"
             fi
        elif [ "$forwarding_choice" ==  "4" ] ; then
             printf "Destination Port Number:"
             read port_number
             command=$command"tcp,tp_dst=$port_number"
        fi
        
        printf "Choose Forwarding Interface(write drop if you want to drop this specific traffic):"
        read forwarding_interface
        if [ "$forwarding_interface" ==  "drop" ] ; then
            command=$command",action=drop"
        else
            #To-Do: Make Sure Interface Exists
            forwarding_port=$(sudo ovs-vsctl get Interface $forwarding_interface ofport)
            command=$command",action=output:$forwarding_port"
        fi
    fi
    echo $command
    eval $command

elif [ $1 == "-del_ft" ] ; then
    printf "name of the ovs bridge:"
    read bridge_name  
    printf "Do you want to delete all or specific:"
    read del_type
    if [ $del_type == "all" ] ; then
        sudo ovs-ofctl del-flows $bridge_name
    elif [ $del_type == "specific" ] ; then
        sudo ovs-ofctl dump-flows $bridge_name
        printf "\nCopy/Paste the match rule(n_bytes=XXX, <match rule> ,action=YYY):"
        read match_rule
        sudo ovs-ofctl del-flows $bridge_name "$match_rule"
    fi

elif [ $1 == "-mac_addresses" ] ; then
    printf "name of the ovs bridge:"
    read bridge_name  
    sudo ovs-appctl fdb/show $bridge_name


else
    printf "$0: exactly 1 arguments expected\n"
    printf "Usage: ./simple_setup.sh <command>\n"
    printf "Commands:\n"
    printf "\t-h: help\n"
    printf "\t-c: create setup\n"
    printf "\t-d: delete setup\n"
    printf "\t-t: get terminals\n"
    printf "\t-show: show ovs configuration\n"
    printf "\t-bridges: list ovs bridges\n"
    printf "\t-ports: list ports on specific ovs bridge\n"
    printf "\t-get_fail_mode:get current fail mode\n"
    printf "\t-set_fail_mode:what to do if could not reach to controller\n"
    printf "\t-show_ft: dump the flow table\n"
    printf "\t-add_ft: add flow table entry\n"
    printf "\t-del_ft: delete all flow table entries\n"
    printf "\t-mac_addresses: dump the learned mac addresses\n"
fi



