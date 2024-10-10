#!/bin/bash
#This is simple script used by the author to run the below commands when testing the code. 
# Go to the parent directory
cd ..

# Remove the directory CSE3/ if it exists
rm -rf CSE3/

# Clone the CSE3 repository
git clone https://github.com/zaidlaffta/CSE3

# Change into the CSE3 directory
cd CSE3/

# Build the project for micaz and simulation
make micaz sim

# Run the Python script
python TestSim.py
