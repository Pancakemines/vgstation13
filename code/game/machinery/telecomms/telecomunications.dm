

/*
	Hello, friends, this is Doohl from sexylands. You may be wondering what this
	monstrous code file is. Sit down, boys and girls, while I tell you the tale.


	The machines defined in this file were designed to be compatible with any radio
	signals, provided they use subspace transmission. Currently they are only used for
	headsets, but they can eventually be outfitted for real COMPUTER networks. This
	is just a skeleton, ladies and gentlemen.

	Look at radio.dm for the prequel to this code.
*/

var/global/list/obj/machinery/telecomms/telecomms_list = list()

/obj/machinery/telecomms
	var/list/links = list() // list of machines this machine is linked to
	var/traffic = 0 // value increases as traffic increases
	var/netspeed = 5 // how much traffic to lose per tick (50 gigabytes/second * netspeed)
	var/list/autolinkers = list() // list of text/number values to link with
	var/id = "NULL" // identification string
	var/network = "NULL" // the network of the machinery

	var/list/freq_listening = list() // list of frequencies to tune into: if none, will listen to all

	var/machinetype = 0 // just a hacky way of preventing alike machines from pairing
	var/toggled = 1 	// Is it toggled on
	var/on = 1
	var/delay = 10 // how many process() ticks to delay per heat
	var/emptime = 0 //How much longer are we receiving interference?
	var/heating_power = 40000 // how much heat to transfer to the environment
	var/long_range_link = 0	// Can you link it across Z levels or on the otherside of the map? (Relay & Hub)
	var/hide = 0				// Is it a hidden machine?
	var/listening_level = 0	// 0 = auto set in New() - this is the z level that the machine is listening to.

	var/moody_state

	use_auto_lights = 1
	light_power_on = 0.5
	light_range_on = 1

	hack_abilities = list(
		/datum/malfhack_ability/toggle/disable,
		/datum/malfhack_ability/oneuse/overload_quiet,
	)

/obj/machinery/telecomms/proc/relay_information(datum/signal/signal, filter, copysig, amount = 20)
	// relay signal to all linked machinery that are of type [filter]. If signal has been sent [amount] times, stop sending
#ifdef SAY_DEBUG
	var/mob/mob = signal.data["mob"]
	var/datum/language/language = signal.data["language"]
	var/langname = (language ? language.name : "No language")
#endif
	say_testing(mob, "[src] relay_information start, language [langname]")
	if(!on)
		return
	var/send_count = 0

	signal.data["slow"] += rand(0, round((100-get_integrity()))) // apply some lag based on integrity TODO: delet this

	// Apply some lag based on traffic rates
	var/netlag = round(traffic / 50)
	if(netlag > signal.data["slow"])
		signal.data["slow"] = netlag

// Loop through all linked machines and send the signal or copy.
	for(var/obj/machinery/telecomms/machine in links)
		if(!machine.loc)
			world.log << "DEBUG: telecomms machine has null loc: [machine.name]"
			continue
		if(filter && !istype( machine, text2path(filter) ))
			continue
		if(!machine.on)
			continue
		if(amount && send_count >= amount)
			break
		if(machine.loc.z != listening_level)
			if(long_range_link == 0 && machine.long_range_link == 0)
				continue
		// If we're sending a copy, be sure to create the copy for EACH machine and paste the data
		var/datum/signal/copy = new /datum/signal
		if(copysig)

			copy.transmission_method = 2
			copy.frequency = signal.frequency
			// Copy the main data contents! Workaround for some nasty bug where the actual array memory is copied and not its contents.
			copy.data = list(
				"mob" = signal.data["mob"],
				"language" = signal.data["language"],
				"mobtype" = signal.data["mobtype"],
				"realname" = signal.data["realname"],
				"name" = signal.data["name"],
				"job" = signal.data["job"],
				"key" = signal.data["key"],
				"vmask" = signal.data["vmask"],
				"compression" = signal.data["compression"],
				"message" = signal.data["message"],
				"radio" = signal.data["radio"],
				"slow" = signal.data["slow"],
				"traffic" = signal.data["traffic"],
				"type" = signal.data["type"],
				"server" = signal.data["server"],
				"reject" = signal.data["reject"],
				"level" = signal.data["level"],
				"lquote" = signal.data["lquote"],
				"rquote" = signal.data["rquote"],
				"message_classes" = signal.data["message_classes"],
				"wrapper_classes" = signal.data["wrapper_classes"],
				"trace" = signal.data["trace"]
			)

			// Keep the "original" signal constant
			if(!signal.data["original"])
				copy.data["original"] = signal
			else
				copy.data["original"] = signal.data["original"]

		else
			copy = null


		send_count++
		if(machine.is_freq_listening(signal))
			machine.traffic++

		if(copysig && copy)
			machine.receive_information(copy, src)
		else
			machine.receive_information(signal, src)


	if(send_count > 0 && is_freq_listening(signal))
		traffic++
	return send_count

/obj/machinery/telecomms/proc/relay_direct_information(datum/signal/signal, obj/machinery/telecomms/machine)
	// send signal directly to a machine
	machine.receive_information(signal, src)

/obj/machinery/telecomms/proc/receive_information(datum/signal/signal, obj/machinery/telecomms/machine_from)
	// receive information from linked machinery
	return

/obj/machinery/telecomms/proc/is_freq_listening(datum/signal/signal)
	// return 1 if found, 0 if not found
	if(!signal)
		return 0
	if((!freq_listening.len) || (freq_listening.Find(signal.frequency)))
		return 1
	else
		return 0


/obj/machinery/telecomms/New()
	telecomms_list += src
	..()

	//Set the listening_level if there's none.
	if(!listening_level)
		//Defaults to our Z level!
		var/turf/position = get_turf(src)
		listening_level = position.z

/obj/machinery/telecomms/initialize()
	if(autolinkers.len)
		// Links nearby machines
		if(!long_range_link)
			for(var/obj/machinery/telecomms/T in orange(20, src))
				add_link(T)
		else
			for(var/obj/machinery/telecomms/T in telecomms_list)
				add_link(T)


/obj/machinery/telecomms/Destroy()
	for(var/link in links)
		unlinkFrom(null, link)
	telecomms_list -= src
	..()

// Used in auto linking
/obj/machinery/telecomms/proc/add_link(var/obj/machinery/telecomms/T)
	var/turf/position = get_turf(src)
	var/turf/T_position = get_turf(T)
	if((position.z == T_position.z) || (src.long_range_link && T.long_range_link))
		if(src != T)
			for(var/x in autolinkers)
				if(x in T.autolinkers)
					links |= T
					break

/obj/machinery/telecomms/update_icon()
	overlays.Cut()
	if(on)
		update_moody_light('icons/lighting/moody_lights.dmi', moody_state)
		icon_state = initial(icon_state)
	else
		kill_moody_light()
		icon_state = "[initial(icon_state)]_off"
	if(panel_open)
		overlays += "[initial(icon_state)]_panel"

/obj/machinery/telecomms/proc/update_power()
	if(toggled)
		if(stat & (BROKEN|NOPOWER|EMPED|FORCEDISABLE) || get_integrity() <= 0) // if powered, on. if not powered, off. if too damaged, off
			on = FALSE
		else
			on = TRUE
	else
		on = FALSE

/obj/machinery/telecomms/proc/update_power_and_icon()
	update_power()
	update_icon()

/obj/machinery/telecomms/power_change()
	..()
	update_power_and_icon()

/obj/machinery/telecomms/process()
	update_power()

	// Check heat and generate some
	checkheat()

	if(emptime > 0)
		stat |= EMPED
		update_power_and_icon()
		emptime -= 1
	else
		stat &= ~EMPED
		update_power_and_icon()

	if(traffic > 0)
		traffic -= netspeed

/obj/machinery/telecomms/emp_act(severity)
	if(prob(100/severity))
		if(!(stat & EMPED))
			emptime = rand(300/severity-2, 300/severity+2)
	..()

/obj/machinery/telecomms/proc/boost_signal()
	if(emptime)
		emptime = 0
		update_power_and_icon()
		heating_power *= 2
		spawn(3000)
			heating_power = initial(heating_power)
		return 1
	return 0

/obj/machinery/telecomms/proc/checkheat()
	// Checks heat from the environment and applies any integrity damage
	var/datum/gas_mixture/environment = loc.return_air()
	if(environment.temperature > T20C + 20)
		set_integrity(get_integrity() - 1)
		if(get_integrity() <= 0)
			update_power()
	if(delay > 0)
		delay--
		return
	if(on && traffic > 0)
		produce_heat()
		delay = initial(delay)

/obj/machinery/telecomms/proc/produce_heat()
	if(!heating_power)
		return
	if(!(stat & (NOPOWER|BROKEN|FORCEDISABLE))) //Blatently stolen from space heater.
		var/turf/simulated/L = loc
		if(istype(L))
			var/datum/gas_mixture/env = L.return_air()
			env.add_thermal_energy(heating_power)
			use_power(heating_power / 1000) // This doesn't work?
/*
	The receiver idles and receives messages from subspace-compatible radio equipment;
	primarily headsets. They then just relay this information to all linked devices,
	which can would probably be network hubs.

	Link to Processor Units in case receiver can't send to bus units.
*/

/obj/machinery/telecomms/receiver
	name = "telecommunications subspace receiver"
	icon = 'icons/obj/machines/telecomms.dmi'
	icon_state = "receiver"
	moody_state = "overlay_receiver"
	desc = "This machine has a dish-like shape and green lights. It is designed to detect and process subspace radio activity."
	density = 1
	anchored = 1
	use_power = MACHINE_POWER_USE_IDLE
	idle_power_usage = 30
	machinetype = 1

	var/blackout_active = FALSE
	hack_abilities = list(
		/datum/malfhack_ability/toggle/disable,
		/datum/malfhack_ability/oneuse/overload_quiet,
		/datum/malfhack_ability/toggle/radio_blackout
	)


/obj/machinery/telecomms/receiver/New()
	..()

	component_parts = newlist(
		/obj/item/weapon/circuitboard/telecomms/receiver,
		/obj/item/weapon/stock_parts/subspace/ansible,
		/obj/item/weapon/stock_parts/subspace/filter,
		/obj/item/weapon/stock_parts/manipulator,
		/obj/item/weapon/stock_parts/manipulator,
		/obj/item/weapon/stock_parts/micro_laser
	)

	RefreshParts()

/obj/machinery/telecomms/receiver/Destroy()
	if(blackout_active)
		malf_radio_blackout = FALSE
	..()

/obj/machinery/telecomms/receiver/receive_signal(datum/signal/signal)
#ifdef SAY_DEBUG
	var/mob/mob = signal.data["mob"]
	var/datum/language/language = signal.data["language"]
	var/langname = (language ? language.name : "No language")
	say_testing(mob, "[src] received radio signal from us, language [langname]")
#endif

	if(!on) // has to be on to receive messages
		return
	if(!signal)
		return
	if(!check_receive_level(signal))
		return
	say_testing(mob, "[src] is on, has signal, and receive is good")

	if(signal.transmission_method == 2)

		if(is_freq_listening(signal)) // detect subspace signals
			signal.data["traffic"] += 1 //Valid step point.
			if(signal.data["trace"])
				var/obj/machinery/computer/telecomms/monitor/M = signal.data["trace"]
				M.receive_trace(src, "Hub or Bus")

			//Remove the level and then start adding levels that it is being broadcasted in.
			signal.data["level"] = list()

			var/can_send = relay_information(signal, "/obj/machinery/telecomms/hub") // ideally relay the copied information to relays
			if(!can_send)
				relay_information(signal, "/obj/machinery/telecomms/bus") // Send it to a bus instead, if it's linked to one


		else
			say_testing(mob, "[src] is not listening")
	else
		say_testing(mob, "bad transmission method")

	update_moody_light('icons/lighting/moody_lights.dmi', "overlay_receiver_receive")
	spawn(22)
		update_moody_light('icons/lighting/moody_lights.dmi', moody_state)
	flick("receiver_receive", src)

/obj/machinery/telecomms/receiver/proc/check_receive_level(datum/signal/signal)


	if(signal.data["level"] != listening_level)
		for(var/obj/machinery/telecomms/hub/H in links)
			var/list/connected_levels = list()
			for(var/obj/machinery/telecomms/relay/R in H.links)
				if(R.can_receive(signal))
					connected_levels |= R.listening_level
			if(signal.data["level"] in connected_levels)
				return 1
		return 0
	return 1


/*
	The HUB idles until it receives information. It then passes on that information
	depending on where it came from.

	This is the heart of the Telecommunications Network, sending information where it
	is needed. It mainly receives information from long-distance Relays and then sends
	that information to be processed. Afterwards it gets the uncompressed information
	from Servers/Buses and sends that back to the relay, to then be broadcasted.
*/

/obj/machinery/telecomms/hub
	name = "telecommunications hub"
	icon = 'icons/obj/machines/telecomms.dmi'
	icon_state = "hub"
	moody_state = "overlay_hub"
	desc = "A mighty piece of hardware used to send/receive massive amounts of data."
	density = 1
	anchored = 1
	use_power = MACHINE_POWER_USE_IDLE
	idle_power_usage = 80
	machinetype = 7
	long_range_link = 1
	netspeed = 40

/obj/machinery/telecomms/hub/New()
	..()

	component_parts = newlist(
		/obj/item/weapon/circuitboard/telecomms/hub,
		/obj/item/weapon/stock_parts/subspace/filter,
		/obj/item/weapon/stock_parts/subspace/filter,
		/obj/item/weapon/stock_parts/manipulator,
		/obj/item/weapon/stock_parts/manipulator
	)

	RefreshParts()

/obj/machinery/telecomms/hub/receive_information(datum/signal/signal, obj/machinery/telecomms/machine_from)
	if(is_freq_listening(signal))
		signal.data["traffic"] += 1 //Valid step point.
		if(istype(machine_from, /obj/machinery/telecomms/receiver))
			if(signal.data["trace"])
				var/obj/machinery/computer/telecomms/monitor/M = signal.data["trace"]
				M.receive_trace(src, "Bus")
			//If the signal is compressed, send it to the bus.
			relay_information(signal, "/obj/machinery/telecomms/bus", 1) // ideally relay the copied information to bus units
		else
			if(signal.data["trace"])
				var/obj/machinery/computer/telecomms/monitor/M = signal.data["trace"]
				M.receive_trace(src, "Broadcaster")
			// Get a list of relays that we're linked to, then send the signal to their levels.
			relay_information(signal, "/obj/machinery/telecomms/relay", 1)
			relay_information(signal, "/obj/machinery/telecomms/broadcaster", 1) // Send it to a broadcaster.


/*
	The relay idles until it receives information. It then passes on that information
	depending on where it came from.

	The relay is needed in order to send information pass Z levels. It must be linked
	with a HUB, the only other machine that can send/receive pass Z levels.
*/

/obj/machinery/telecomms/relay
	name = "telecommunications relay"
	icon = 'icons/obj/machines/telecomms.dmi'
	icon_state = "relay"
	moody_state = "overlay_relay"
	desc = "A mighty piece of hardware used to send massive amounts of data far away."
	density = 1
	anchored = 1
	use_power = MACHINE_POWER_USE_IDLE
	idle_power_usage = 30
	machinetype = 8
	heating_power = 0
	netspeed = 5
	long_range_link = 1
	var/broadcasting = 1
	var/receiving = 1

/obj/machinery/telecomms/relay/New()
	..()

	component_parts = newlist(
		/obj/item/weapon/circuitboard/telecomms/relay,
		/obj/item/weapon/stock_parts/subspace/filter,
		/obj/item/weapon/stock_parts/subspace/filter,
		/obj/item/weapon/stock_parts/manipulator,
		/obj/item/weapon/stock_parts/manipulator
	)

	RefreshParts()

/obj/machinery/telecomms/relay/receive_information(datum/signal/signal, obj/machinery/telecomms/machine_from)
	/*var/obj/machinery/computer/telecomms/monitor/M = signal.data["trace"]
	if(M) Don't really care about relays
		M.receive_trace(src, "None")*/
	// Add our level and send it back
	if(can_send(signal))
		signal.data["level"] |= listening_level

// Checks to see if it can send/receive.

/obj/machinery/telecomms/relay/proc/can(datum/signal/signal)
	if(!on)
		return 0
	if(!is_freq_listening(signal))
		return 0
	return 1

/obj/machinery/telecomms/relay/proc/can_send(datum/signal/signal)
	if(!can(signal))
		return 0
	return broadcasting

/obj/machinery/telecomms/relay/proc/can_receive(datum/signal/signal)
	if(!can(signal))
		return 0
	return receiving

/*
	The bus mainframe idles and waits for hubs to relay them signals. They act
	as junctions for the network.

	They transfer uncompressed subspace packets to processor units, and then take
	the processed packet to a server for logging.

	Link to a subspace hub if it can't send to a server.
*/

/obj/machinery/telecomms/bus
	name = "telecommunications bus"
	icon = 'icons/obj/machines/telecomms.dmi'
	icon_state = "bus"
	moody_state = "overlay_bus"
	desc = "A mighty piece of hardware used to send massive amounts of data quickly."
	density = 1
	anchored = 1
	use_power = MACHINE_POWER_USE_IDLE
	idle_power_usage = 50
	machinetype = 2
	netspeed = 40
	var/change_frequency = 0

/obj/machinery/telecomms/bus/New()
	..()

	component_parts = newlist(
		/obj/item/weapon/circuitboard/telecomms/bus,
		/obj/item/weapon/stock_parts/subspace/filter,
		/obj/item/weapon/stock_parts/manipulator,
		/obj/item/weapon/stock_parts/manipulator
	)

	RefreshParts()

/obj/machinery/telecomms/bus/receive_information(datum/signal/signal, obj/machinery/telecomms/machine_from)

	if(is_freq_listening(signal))
		signal.data["traffic"] += 1 //Valid step point.
		var/obj/machinery/computer/telecomms/monitor/M = signal.data["trace"]

		if(change_frequency)
			signal.frequency = change_frequency

		if(!istype(machine_from, /obj/machinery/telecomms/processor) && machine_from != src) // Signal must be ready (stupid assuming machine), let's send it
			// send to one linked processor unit
			if(M)
				M.receive_trace(src, "Processor")
			var/send_to_processor = relay_information(signal, "/obj/machinery/telecomms/processor")

			if(send_to_processor)
				return
			// failed to send to a processor, relay information anyway
			signal.data["slow"] += rand(1, 5) // slow the signal down only slightly
			src.receive_information(signal, src)

		// Try sending it!
		if(M)
			M.receive_trace(src, "Server, Hub, Broadcaster, or Bus")
		var/list/try_send = list("/obj/machinery/telecomms/server", "/obj/machinery/telecomms/hub", "/obj/machinery/telecomms/broadcaster", "/obj/machinery/telecomms/bus")
		var/i = 0
		for(var/send in try_send)
			if(i)
				signal.data["slow"] += rand(0, 1) // slow the signal down only slightly
			i++
			var/can_send = relay_information(signal, send)
			if(can_send)
				break



/*
	The processor is a very simple machine that decompresses subspace signals and
	transfers them back to the original bus. It is essential in producing audible
	data.

	Link to servers if bus is not present
*/

/obj/machinery/telecomms/processor
	name = "telecommunications processor"
	icon = 'icons/obj/machines/telecomms.dmi'
	icon_state = "processor"
	moody_state = "overlay_processor"
	desc = "This machine is used to process large quantities of information."
	density = 1
	anchored = 1
	use_power = MACHINE_POWER_USE_IDLE
	idle_power_usage = 30
	machinetype = 3
	delay = 5
	var/process_mode = 1 // 1 = Uncompress Signals, 0 = Compress Signals

/obj/machinery/telecomms/processor/New()
	..()

	component_parts = newlist(
		/obj/item/weapon/circuitboard/telecomms/processor,
		/obj/item/weapon/stock_parts/subspace/filter,
		/obj/item/weapon/stock_parts/manipulator,
		/obj/item/weapon/stock_parts/manipulator,
		/obj/item/weapon/stock_parts/manipulator,
		/obj/item/weapon/stock_parts/subspace/treatment,
		/obj/item/weapon/stock_parts/subspace/treatment,
		/obj/item/weapon/stock_parts/subspace/analyzer,
		/obj/item/weapon/stock_parts/subspace/amplifier
	)

	RefreshParts()

/obj/machinery/telecomms/processor/receive_information(datum/signal/signal, obj/machinery/telecomms/machine_from)
	if(is_freq_listening(signal))
		signal.data["traffic"] += 1 //Valid step point.
		if(signal.data["trace"])
			var/obj/machinery/computer/telecomms/monitor/M = signal.data["trace"]
			M.receive_trace(src, "Bus")

		if(process_mode)
			signal.data["compression"] = 0 // uncompress subspace signal
		else
			signal.data["compression"] = 100 // even more compressed signal

		if(istype(machine_from, /obj/machinery/telecomms/bus))
			relay_direct_information(signal, machine_from) // send the signal back to the machine
		else // no bus detected - send the signal to servers instead
			signal.data["slow"] += rand(5, 10) // slow the signal down
			relay_information(signal, "/obj/machinery/telecomms/server")


/*
	The server logs all traffic and signal data. Once it records the signal, it sends
	it to the subspace broadcaster.

	Store a maximum of 100 logs and then deletes them.
*/


/obj/machinery/telecomms/server
	name = "telecommunications server"
	icon = 'icons/obj/machines/telecomms.dmi'
	icon_state = "server"
	moody_state = "overlay_server"
	desc = "A machine used to store data and network statistics."
	density = 1
	anchored = 1
	use_power = MACHINE_POWER_USE_IDLE
	idle_power_usage = 15
	machinetype = 4
	var/list/log_entries = list()
	var/list/stored_names = list()
	var/list/TrafficActions = list()
	var/logs = 0 // number of logs
	var/totaltraffic = 0 // gigabytes (if > 1024, divide by 1024 -> terrabytes)

	var/list/memory = list()	// stored memory
	var/rawcode = ""	// the code to compile (raw text)
	var/datum/n_Compiler/TCS_Compiler/Compiler	// the compiler that compiles and runs the code
	var/autoruncode = 0		// 1 if the code is set to run every time a signal is picked up

	var/encryption = "null" // encryption key: ie "password"
	var/salt = "null"		// encryption salt: ie "123comsat"
							// would add up to md5("password123comsat")
	var/language = "human"
	var/obj/item/device/radio/headset/server_radio = null
	var/last_signal = 0 	// Last time it sent a signal

	var/list/freq_names = list() // Names to associate each frequency with on broadcast, if any

/obj/machinery/telecomms/server/New()
	..()
	Compiler = new()
	Compiler.Holder = src
	server_radio = new()

	component_parts = newlist(
		/obj/item/weapon/circuitboard/telecomms/server,
		/obj/item/weapon/stock_parts/subspace/filter,
		/obj/item/weapon/stock_parts/manipulator,
		/obj/item/weapon/stock_parts/manipulator
	)

	RefreshParts()

/obj/machinery/telecomms/server/Destroy()
	// Garbage collects all the NTSL datums.
	if(Compiler)
		Compiler.GC()
		Compiler = null
	..()

/obj/machinery/telecomms/server/receive_information(datum/signal/signal, obj/machinery/telecomms/machine_from)

	if(signal.data["message"])

		if(is_freq_listening(signal))
			signal.data["traffic"] += 1 //Valid step point.
			if(signal.data["trace"])
				var/obj/machinery/computer/telecomms/monitor/monitor = signal.data["trace"]
				monitor.receive_trace(src, "Hub or Broadcaster")

			if(traffic > 0)
				totaltraffic += traffic // add current traffic to total traffic

			//Is this a test signal? Bypass logging
			if(signal.data["type"] != 4)

				// If signal has a message and appropriate frequency

				update_logs()

				var/datum/comm_log_entry/log = new
				var/mob/M = signal.data["mob"]
				// Copy the signal.data entries we want
				log.parameters["mobtype"] = signal.data["mobtype"]
				log.parameters["job"] = signal.data["job"]
				log.parameters["key"] = signal.data["key"]
				log.parameters["message"] = signal.data["message"]
				log.parameters["name"] = signal.data["name"]
				log.parameters["realname"] = signal.data["realname"]

				if(!istype(M, /mob/new_player) && istype(M))
					log.parameters["uspeech"] = M.universal_speak
				else
					log.parameters["uspeech"] = 0



				// If the signal is still compressed, make the log entry gibberish
				if(signal.data["compression"] > 0)
					log.parameters["message"] = Gibberish(signal.data["message"], signal.data["compression"] + 50)
					log.parameters["job"] = Gibberish(signal.data["job"], signal.data["compression"] + 50)
					log.parameters["name"] = Gibberish(signal.data["name"], signal.data["compression"] + 50)
					log.parameters["realname"] = Gibberish(signal.data["realname"], signal.data["compression"] + 50)
					log.input_type = "Corrupt File"

				// Log and store everything that needs to be logged
				log_entries.Add(log)
				if(!(signal.data["name"] in stored_names))
					stored_names.Add(signal.data["name"])
				logs++
				signal.data["server"] = src

				// Give the log a name
				var/identifier = num2text( rand(-1000,1000) + world.time )
				log.name = "data packet ([md5(identifier)])"

				if(Compiler && autoruncode)
					Compiler.Run(signal)	// execute the code

			var/can_send = relay_information(signal, "/obj/machinery/telecomms/hub")
			if(!can_send)
				relay_information(signal, "/obj/machinery/telecomms/broadcaster")


/obj/machinery/telecomms/server/proc/setcode(var/t)
	if(t)
		if(istext(t))
			rawcode = t

/obj/machinery/telecomms/server/proc/admin_log(var/mob/mob)
	var/msg = "[key_name(mob)] has compiled a script to [src.id]"

	diary << msg
	diary << rawcode

	investigation_log(I_NTSL, "[msg]<br /><pre>[rawcode]</pre>")

	if (length(rawcode)) // Let's not bother the admins for empty code.
		message_admins("[msg] ([formatJumpTo(mob)])", 0, 1)

/obj/machinery/telecomms/server/proc/compile(var/mob/user)


	if(Compiler)
		admin_log(user)
		return Compiler.Compile(rawcode)

/obj/machinery/telecomms/server/proc/update_logs()
	// start deleting the very first log entry
	if(logs >= 400)
		for(var/i = 1, i <= logs, i++) // locate the first garbage collectable log entry and remove it
			var/datum/comm_log_entry/L = log_entries[i]
			if(L.garbage_collector)
				log_entries.Remove(L)
				logs--
				break

/obj/machinery/telecomms/server/proc/add_entry(var/content, var/input)
	var/datum/comm_log_entry/log = new
	var/identifier = num2text( rand(-1000,1000) + world.time )
	log.name = "[input] ([md5(identifier)])"
	log.input_type = input
	log.parameters["message"] = content
	log_entries.Add(log)
	update_logs()

// Simple log entry datum

/datum/comm_log_entry
	var/parameters = list() // carbon-copy to signal.data[]
	var/name = "data packet (#)"
	var/garbage_collector = 1 // if set to 0, will not be garbage collected
	var/input_type = "Speech File"
