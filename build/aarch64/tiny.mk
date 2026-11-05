# tiny.mk — mk execution-evidence input (06-06, RESEARCH OQ-2).
# One trivial target with an echo recipe: the donor guest's hmk runs
# `mk -f /boot/tiny.mk` and the sweep asserts the marker string in
# mk's output (the recipe echo + its result).
all:V:
	echo __TINY_MK_OK__
