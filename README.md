# NoC_Design_Trojan_Project

Commit6:
Haseeb's Original Code for NoC and Power Management.
Run simulation for atleast 50us.

Commit7: 
Adding SourceID variable to the packets. Also the parameter of SourceID is added to rc_arb_xb.v 

Commit8:
Added a random traffic(manually) and set the full signal in network interface to zero.
So thath network always receive packets and never get full. 

Commit9:
Updating the Readme file after Random Traffic(manually) added 

Commit10:
Python Script to clean the "s_flits_in.csv" and "s_flits_out.csv" files.

Commit11:
Adding new branch name "Trojan". And making this commit on Trojan Branch
Adding router_plus_trojan.v file 
Description: The trojan is present in router 7 and send any packet coming to its input ports to Node 12  which has a malicious program running.
			 The trojan is tested on single flit and the values are hard coded. 



