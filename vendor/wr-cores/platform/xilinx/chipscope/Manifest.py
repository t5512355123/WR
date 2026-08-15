if (syn_device[0:4].upper()=="XC6S"):    # Spartan6
	files = ["chipscope_spartan6_icon.ngc", "chipscope_spartan6_ila.ngc"]
elif (syn_device[0:4].upper()=="XC5V"): # Virtex5
	files = ["chipscope_virtex5_icon.ngc", "chipscope_virtex5_ila.ngc" ]
