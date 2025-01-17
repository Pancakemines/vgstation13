var/global/list/igniters = list()
/obj/machinery/igniter
	name = "igniter"
	desc = "It's useful for igniting plasma."
	icon = 'icons/obj/stationobjs.dmi'
	icon_state = "igniter1"
	var/on = 1.0
	var/obj/item/device/assembly_holder/assembly=null
	anchored = 1.0
	use_power = MACHINE_POWER_USE_IDLE
	idle_power_usage = 2
	active_power_usage = 4

	ghost_read = 0 // Deactivate ghost touching.
	ghost_write = 0

/obj/machinery/igniter/attack_paw(mob/user as mob)
	if ((ticker && ticker.mode.name == "monkey"))
		return src.attack_hand(user)
	return

/obj/machinery/igniter/attack_hand(mob/user as mob)
	if(..())
		return
	add_fingerprint(user)

	use_power(50)
	src.on = !( src.on )
	src.icon_state = text("igniter[]", src.on)
	return

/obj/machinery/igniter/process()	//ugh why is this even in process()?
	if (src.on && !(stat & (NOPOWER|FORCEDISABLE)) )
		try_hotspot_expose(1000,MEDIUM_FLAME,1)
	return 1

/obj/machinery/igniter/proc/toggle_state()
	use_power(50)
	src.on = !( src.on )
	src.icon_state = text("igniter[]", src.on)
	return

/obj/machinery/igniter/New()
	..()
	icon_state = "igniter[on]"
	igniters += src

/obj/machinery/igniter/Destroy()
	igniters -= src
	..()

/obj/machinery/igniter/power_change()
	if(!( stat & (FORCEDISABLE|NOPOWER)) )
		icon_state = "igniter[src.on]"
	else
		icon_state = "igniter0"

/obj/machinery/igniter/attackby(var/obj/item/weapon/W as obj, var/mob/user as mob)
	if(iswelder(W) && src.assembly)
		var/obj/item/tool/weldingtool/WT = W
		to_chat(user, "<span class='notice'>You begin to cut \the [src] off the floor...</span>")
		if (WT.do_weld(user, src, 40, 0))
			user.visible_message( \
				"[user] disassembles \the [src].", \
				"<span class='notice'>You have disassembled \the [src].</span>", \
				"You hear welding.")
			src.assembly.forceMove(src.loc)
			qdel(src)
			return
		else
			to_chat(user, "<span class='warning'>You need more welding fuel to do that.</span>")
			return 1


// Wall mounted remote-control igniter.

/obj/machinery/sparker
	name = "Mounted igniter"
	desc = "A wall-mounted ignition device."
	icon = 'icons/obj/stationobjs.dmi'
	icon_state = "migniter"
	var/disable = 0
	var/last_spark = 0
	var/base_state = "migniter"
	anchored = 1

	ghost_read = 0 // Deactivate ghost touching.
	ghost_write = 0

/obj/machinery/sparker/New()
	..()
	igniters += src

/obj/machinery/sparker/Destroy()
	igniters -= src
	..()

/obj/machinery/sparker/power_change()
	if ( powered() && disable == 0 )
		stat &= ~NOPOWER
		icon_state = "[base_state]"
//		src.sd_SetLuminosity(2)
	else
		stat |= ~NOPOWER
		icon_state = "[base_state]-p"
//		src.sd_SetLuminosity(0)

/obj/machinery/sparker/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if(istype(W, /obj/item/device/detective_scanner))
		return
	if (W.is_screwdriver(user))
		add_fingerprint(user)
		src.disable = !src.disable
		if (src.disable)
			user.visible_message("<span class='warning'>[user] has disabled the [src]!</span>", "<span class='warning'>You disable the connection to the [src].</span>")
			icon_state = "[base_state]-d"
		if (!src.disable)
			user.visible_message("<span class='warning'>[user] has reconnected the [src]!</span>", "<span class='warning'>You fix the connection to the [src].</span>")
			if(src.powered())
				icon_state = "[base_state]"
			else
				icon_state = "[base_state]-p"

/obj/machinery/sparker/attack_ai(var/mob/user)
	if (src.anchored)
		return do_spark()
	else
		return

/obj/machinery/sparker/proc/do_spark()
	if (!(powered()))
		return

	if ((src.disable) || (src.last_spark && world.time < src.last_spark + 50))
		return


	flick("[base_state]-spark", src)
	spark(src, 2, surfaceburn = TRUE)
	src.last_spark = world.time
	use_power(1000)
	try_hotspot_expose(1000,MEDIUM_FLAME,1)
	return 1

/obj/machinery/sparker/emp_act(severity)
	if(stat & (BROKEN|NOPOWER|FORCEDISABLE))
		..(severity)
		return
	do_spark()
	..(severity)

/obj/machinery/ignition_switch/attack_paw(mob/user as mob)
	return src.attack_hand(user)

/obj/machinery/ignition_switch/attackby(obj/item/weapon/W, mob/user as mob)
	return src.attack_hand(user)

/obj/machinery/ignition_switch/attack_hand(mob/user as mob)
	playsound(src,'sound/misc/click.ogg',30,0,-1)
	if(stat & (NOPOWER|BROKEN|FORCEDISABLE))
		return
	if(active)
		return

	use_power(5)

	active = 1
	icon_state = "launcheract"

	for(var/obj/machinery/sparker/M in igniters)
		if (M.id_tag == src.id_tag)
			spawn( 0 )
				M.do_spark()

	for(var/obj/machinery/igniter/M in igniters)
		if(M.id_tag == src.id_tag)
			use_power(50)
			M.on = !( M.on )
			M.icon_state = text("igniter[]", M.on)

	sleep(50)

	icon_state = "launcherbtt"
	active = 0

	return
