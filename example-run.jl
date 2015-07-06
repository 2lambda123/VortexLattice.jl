#----------------------------------------------------------------------
# This version assumes (one) symmetric wing.
#
# Author: Ryan Barrett
# Based off VLM in MATLAB created by S. Andrew Ning
# ----------------------------------------------------------------------


# include statements and packages
# using Gadfly
# using Debug
using Polynomials
using PyPlot
include("types_def.jl")
include("VLM_functions.jl")
wing_2 = wing_def([29 65], [43 26 11], [0 0 0]*pi/180, [0.13 0.12 0.11], [25 30]*pi/180, [0 0], 50)
wing = wing_def([10], [4 4], [0 0]*pi/180, [0.13 0.12], [25]*pi/180, [0], 10)

# wing geometry - all degrees in radians
# wing.span = [29 65]
# wing.chord = [43 26 11]
# wing.twist = [0 0 0]*pi/180
# wing.tc = [0.13 0.12 0.11]
# wing.sweep = [25 30]*pi/180
# wing.dihedral = [0 0]
# wing.N = 50

wing.span = [10]
wing.chord = [4 4]
wing.twist = [0 0]*pi/180
wing.tc = [0.13 0.12]
wing.sweep = [25]*pi/180
wing.dihedral = [0]
wing.N = 10

Sref = (wing.chord[1:end-1]+wing.chord[2:end])*wing.span.'
bref = 2*sum(wing.span.*cos(wing.dihedral))
# freestream parameters - 2 methods either specify CL or angle of attack
fs = fs_def(0.78, 5*pi/180, 0.5, "alpha")
fs.mach = 0.78
fs.alpha = 5*pi/180 # only used for 'alpha' method
fs.CL = 0.5 # only used for 'CL' method
fs.method = "alpha"

# reference and other parameters (used for force/moment coefficients)
ref = ref_def(Sref, Sref/bref, 1.4)
ref.S = Sref
ref.c = Sref/bref
ref.CLmax = 1.4

# parasite drag - 2 methods either PASS method or strip theory with a quadratic varition in cl
pdrag = pdrag_def([0.007 0 0.003], 35000, 0.05, "pass")
pdrag.polar = [0.007 0 0.003] # only used in 'quad' method
pdrag.alt = 35000 # only used in 'pass' method
pdrag.xt = 0.05 # only used in 'pass' method
pdrag.method = "pass"

# structures
mvr = mvr_def(2.5, 2.5, 0)
mvr.qN = 2.5 # ratio of mvr dynamic pressure to cruise dynamic pressure
mvr.n = 2.5 # limit load factor
mvr.kbar = 0 # coefficient for area-dependent weight

QC = QC_def([0],[0],[0])
TE = TE_def([0],[0],[0])
LE = LE_def([0],[0],[0])
CP = CP_def([0],[0],[0],[0],[0],[0],[0],[0],[0])

plots = true
(CL, CDi, CDp, CDc, CW, Cmac, cl_margin) = VLM(wing, fs, ref, pdrag, mvr, plots, QC, TE, LE, CP)

