#
# TCL script for creating VHDL descriptions from a Block Design Files
# and starts the ModelsSim simulator with the top level design.
# Hierarchies are supported.
#
# Note: Your top level design entity must reside in a file with the name
#       <toplevel>.bdf or <toplevel>.vhd.
#       You must have a DO file with the name tb_<toplevel>.do
#       for simulation to work. Your DO file must contain all ModelSim
#       commands for the simulation to work (thus also all vcom and
#       vsim commands).
#
# Version 1.3beta11  -  2021/02/02
#
# (c)2021, Jesse op den Brouw, <j.e.j.opdenbrouw@hhs.nl>
# (c)2021, De Haagse Hogeschool [www.hhs.nl]
#
#
# This script works as follows:
#
#  1. It checks if the project is open.
#  2. Finds ModelSim execution path is none is provided. Linux and
#     Windows supported.
#  3. Creates a project database is none is found.
#  4. Finds the top level, checks if the top level entity has an
#     associated file, complains if none is found.
#  5. Loops through all BDF files found in the project environment
#     and creates accompanied VHDL files if needed.
#  6. Removes all VHDL files from accompanied BDF files IN the project
#     directory but NOT in the project environment, but not VHDL files
#     that do NOT have a accompanied BDF file.
#  7. Finds top level filename and creates DO filename.
#  8. Starts ModelSim with DO filename.
#
# Bugs: currently the script can't handle BDF-files outside of the
#       project directory.
#       currenty the script can't handle library elements
#
# Todo: hardening for use on Unices other than Linux
#       option to create Verilog files instead of VHDL files
#       testing on multiple revisions
#       handle files outside the project directory
#       handle library elements

# User input: set to the modelsim path. Keep empty for autodetect.
#set modelsim_exec_path "/opt/altera/12.1sp1/modelsim_ase/linuxaloem/vsim"
set modelsim_exec_path ""

# Print a nice banner
post_message -type info "#############################################"
post_message -type info "BDF to VHDL converter & ModelSim Starter v1.3"
post_message -type info "#############################################"

# Check for project opened.
if {![is_project_open]} { 
	post_message -type error "There's no project open! Please open a project and rerun."
	return False
}

# Export any newly changed/added/removed assignments
export_assignments

# Autodetect ModelSim exec path if none is provided. First, the user
# preferences are consulted, then ModelSim is autodetected. For this to
# work, ModelSim must be installed within the Quartus environment.
if { [string length $modelsim_exec_path] == 0 } {
	post_message -type info "Autodetecting ModelSim path..."
	set opsys [string tolower [lindex $::tcl_platform(os) 0]]
	post_message -type info "OS is: $opsys" 

	# Try to get ModelSim path from user preferences
	set modelsim_exec_path [get_user_option -name EDA_TOOL_PATH_MODELSIM_ALTERA]

	if { [string length $modelsim_exec_path] > 0} {
		# User has entered a path in EDA Tool Options...
		post_message -type info "Found user preference path: $modelsim_exec_path"
		set modelsim_exec_path [string map {"\\" "/"} $modelsim_exec_path]
		# Different OSes...
		switch $opsys {
			linux { append modelsim_exec_path "/vsim" }
			windows { append modelsim_exec_path "/modelsim.exe" }
			default { post_message -type error "Cannot continue: unknowm platform is $opsys. Bailing out."
					return False }
		}
	} else {
		# Tries to find a ModelSim installation directory. Stops if found none is found.
		# Stops if more than one found AND one of them is NOT ModelSim ASE.
		# Continues if ModelSim ASE is found in multiple ModelSIm installations.
		set modelsim_exec_path $quartus(quartus_rootpath)
		append modelsim_exec_path "../"
		switch [llength [set modelsim_list [ glob -nocomplain -path $modelsim_exec_path modelsim* ]]] {
			0 { post_message -type error "ModelSim not installed in Quartus environment! Bailing out."
				return False }
			1 { set modelsim_exec_path [lindex $modelsim_list 0] }
			default { set modelsim_exec_path [lindex $modelsim_list [lsearch $modelsim_list *modelsim_ase]]
				if { [string length $modelsim_exec_path] > 0} {
					post_message -type info "Found ModelSim path for Altera Starter Edition (modelsim_ase)."
				} else {
					post_message -type error "Multiple ModelSim installations found! Bailing out."
					return False
				}
			}
		}
		# Different OSes...
		switch $opsys {
			linux { append modelsim_exec_path "/linuxaloem/vsim" }
			windows { append modelsim_exec_path "/win32aloem/modelsim.exe" }
			default { post_message -type error "Cannot continue: unknowm platform is $opsys. Bailing out."
					return False }
		}
	}
}

# Normalize path name (get rid of ../ and ./ etc)
set modelsim_exec_path [file normalize $modelsim_exec_path]
post_message -type info "ModelSim path: $modelsim_exec_path"

# Check if the ModelSim executable is executable...
if { [file executable $modelsim_exec_path] == 0 } {
	post_message -type error "ModelSim executable cannot be run by current user. Bailing out!" -submsgs {"You should check the path to the executable in this script or via menu" "Tools->Options->EDA Tool Options or your ModelSim installation is corrupt."}
	return False
}

# Set the project directory. This is needed because if you have added a BDF file
# that is not in the project directory (e.g. ../<some_other_dir>/file.bdf),
# Quartus changes the current directory path ([pwd]). Yes, really, it does...
# Please note that BDF files outside the project directory are not supported. 
# The problem is that Quartus creates a VHDL file in that same directory. This
# could overwrite an existing file. There's no option to provide an output
# directory.
set project_directory [get_project_directory]
post_message -type info "Project directory: $project_directory"
cd $project_directory

# Get current revision
# Check if there is a database. If not, create one.
set current_revision ""
if { [catch {get_top_level_entity}] } {
	set current_revision [get_current_revision]
	post_message -type info "There's no compiler database, running Analysis & Synthesis with revision name $current_revision"
	# Running Analysis & Synthesis currenly crashes when there's no file
	# containing the toplevel, that is, you have sole QPF and QSF files,
	# or there's no way to systhesize the design (or any generic error for
	# that matter).
	set status [catch { exec quartus_map --read_settings_files=on --write_settings_files=off $current_revision -c $current_revision } result]
	if { $status != 0 } {
		post_message -type error "Creating database failed! There are five posibilities:"
		post_message -type error "1: you have a project without a file containing the top level description."
		post_message -type error "2: you have a design that cannot be synthesized."
		post_message -type error "3: you have an error in (one of) your design file(s)."
		post_message -type error "4: the current device is not supported in this version of Quartus."
		post_message -type error "5: you changed the target device and/or the device files of the previous/current device are not installed."
		post_message -type error "You can try rerunning the script. Bailing out."
		return False
	}
} else {
	set current_revision [get_current_revision]
}
# Echo the current revision
post_message -type info "Current revision: $current_revision"

# Find top level entity currently !focused! See Quartus:
# Assignments->Settings->General->Top Level Entity
set top_level_entity [get_name_info -info entity_name [get_top_level_entity]]
post_message -type info "Found top level entity : $top_level_entity"

# Find the file containing top level entity
set top_level_entity_file_name [get_name_info -info file_location [get_top_level_entity]]
post_message -type info "Found top level entity file name : $top_level_entity_file_name"

# Check for empty top level filename. Does happen when in a completely stripped
# project the simulation is started (that is: there's no file containing the
# top level entity, but there is a project database). 
if { [string compare $top_level_entity_file_name  ""] == 0} {
	post_message -type error "Top level filename is empty. Please enter a file, rerun Analysis & Synthesis and start again. Bailing out."
	return False;
}

# Create a list of all BDF files in the project DIRECTORY. We need this list
# for later on. If a BDF file is in the project environment, we remove it from
# this list. At the end we have list of BDF files in the project directory but
# not in the project environment.
set all_bdf_design_file_names [glob -nocomplain -type f *.bdf]

# Find all BDF files in project. This excludes BDF files that are in the
# project directory but not in the project environment. For all BDF files in
# the project, create a VHDL file if needed. Currently works for current
# directory level.
post_message -type info "Looping through all BDF-files in project"

set all_bdf_design_file_names_in_project ""
foreach_in_collection asgn_id [get_all_assignments -type global -name BDF_FILE] {

	# Get next BDF file name
	set bdf_design_file_name  [get_assignment_info $asgn_id -value]
	# Add to list (for later use)
	lappend all_bdf_design_file_names_in_project $bdf_design_file_name
	# Remove the BDF file from the the list of all BDF files in the project
	# directory
	set all_bdf_design_file_names [lsearch -all -inline -not -exact $all_bdf_design_file_names $bdf_design_file_name]
	post_message -type info "    Found BDF file $bdf_design_file_name"

	# Test for design files outside of the current project directory and skip
	# them. The problem is that creating a VHDL file from such a BDF file
	# results in a VHDL file in the directory of the BDF file, not in the
	# project directory...
	if { [string compare [file tail $bdf_design_file_name] $bdf_design_file_name] != 0} {
		post_message -type critical_warning "Files outside the project directory are currently not supported! File skipped."
		continue
	}
	set vhdl_design_file_name [file tail [file rootname $bdf_design_file_name]]
	append vhdl_design_file_name ".vhd"

	set generate_vhdl_file 0
	if {![file exists $vhdl_design_file_name]} {
		# VHDL file does not exists and must be generated
		set generate_vhdl_file 1
		post_message -type info "    VHDL file does not exist, creating"
	} else {
		# VHDL file exists, check time stamp
		set vhdl_file_mtime [file mtime $vhdl_design_file_name]
		set bdf_file_mtime [file mtime $bdf_design_file_name]
		if {$vhdl_file_mtime < $bdf_file_mtime} {
			# VHDL file out of date
			set generate_vhdl_file 1
			post_message -type info "    VHDL file out of date, creating"
		}
	}	

	if {$generate_vhdl_file == 1} {
		# Start the Quartus Mapper for generating VHDL description
		post_message -type info "exec quartus_map --read_settings_files=on --write_settings_files=off $current_revision -c $current_revision --convert_bdf_to_vhdl=$bdf_design_file_name"
		exec quartus_map --read_settings_files=on --write_settings_files=off $current_revision -c $current_revision --convert_bdf_to_vhdl=$bdf_design_file_name
	} else {
		post_message -type info "    VHDL file up to date, no need for creating"
	}
}

# All the BDF files in the project directory but NOT in the project environment
if { [llength $all_bdf_design_file_names] > 0} {
	post_message -type info "All remaining BDF files in project directory: $all_bdf_design_file_names"
} else {
	post_message -type info "No remaining BDF files in project directory"
}

# We remove all VHDL files for which a BDF file exists but not in the project
# environment. We do this so that ModelSim will not accidentally compile and
# load them.
foreach files $all_bdf_design_file_names {
	set vhdl_file_to_remove [file rootname $files]
	append vhdl_file_to_remove ".vhd"
	if {[file exists $vhdl_file_to_remove]} {	
		post_message -type info "Removing VHDL file $vhdl_file_to_remove"
		file delete $vhdl_file_to_remove
	} else {
		post_message -type info "No VHDL file $vhdl_file_to_remove found."
	}
}

# Check if the top level file name is what we expected.
if { [string compare [file rootname $top_level_entity_file_name] $top_level_entity] == 0 } {
	# Correct file name
	post_message -type info "Top level file name is correct."

	# Get user supplied ModelSim test bench file name, see if it is used.
	set modelsim_testbench_file_name [get_global_assignment -name EDA_SIMULATION_RUN_SCRIPT -section_id eda_simulation]
	set modelsim_testbench_enable_st [get_global_assignment -name EDA_TEST_BENCH_ENABLE_STATUS -section_id eda_simulation]
	if { ([string length $modelsim_testbench_file_name] > 0) && ([string equal $modelsim_testbench_enable_st "COMMAND_MACRO_MODE"] == 1) } {
		post_message -type info "Found user supplied command file."
	} else {
		# Check for ModelSim DO file name
		set modelsim_testbench_file_name "tb_${top_level_entity}.do"
	} 
	if {[file exists $modelsim_testbench_file_name]} {
		# Found do file, start modelsim
		post_message -type info "Starting ModelSim with do-file $modelsim_testbench_file_name in background (frees Quartus IDE)"
		if { [catch { exec -ignorestderr ${modelsim_exec_path} -do $modelsim_testbench_file_name \& } result ] } {
			# Bummer, modelsim didn't start correctly...
			post_message -type error "ModelSim can't be started. Bailing out."
		}
	} else {
		# Bummer, do file not found or not by name convention
		post_message -type error "DO file not found or not by name convention ($modelsim_testbench_file_name). Bailing out."
	}
} else {
	# Incorrect file name
	post_message -type error "Top level file name is NOT correct ($top_level_entity_file_name,$top_level_entity). Bailing out."
}
