extends RefCounted
## English keys for simulation states. Display strings live in ui/labels.gd, and no logic
## compares them.

const RESOURCES: Array[String] = [
	"ore", "copper", "crystal", "food", "materials", "parts", "components"
]

const B_BUILDING: String = "building"
const B_PENDING: String = "pending"
const B_DISABLED: String = "disabled"
const B_RUNNING: String = "running"
const B_IDLE: String = "idle"
const B_DEPLETED: String = "depleted"
const B_TARGET_FULL: String = "target_full"
const B_NO_INPUT: String = "no_input"
const B_PRIVATE_OPEN: String = "private_open"
const B_RESTRICTED: String = "restricted"

const E_FITTING: String = "fitting_out"
const E_OPEN: String = "open"
const E_RESTRICTED: String = "restricted"
const E_PAUSED: String = "paused"
const E_CLOSED: String = "closed"

const ER_FITTING: String = "fitting_out"
const ER_PAUSED: String = "paused_by_player"
const ER_NO_WORKERS: String = "no_workers"
const ER_NO_CASH: String = "no_cash"
const ER_RUNNING: String = "self_running"
const ER_RECOVERING: String = "recovering"

const SH_JOBS_WORKERS: String = "jobs_workers"
const SH_JOBS_SPECIALISTS: String = "jobs_specialists"
const SH_POWER: String = "power"
const SH_WATER: String = "water"
const SH_DEPLETED: String = "depleted"
const SH_PROCESSOR_INPUT: String = "processor_input"
const SH_NO_PORT: String = "no_port"
const SH_PORT_FULL: String = "port_full"
const SH_STARVING: String = "starving"
const SH_HOUSING: String = "housing"
const SH_POLLUTION: String = "pollution"

const SOURCE_PROCESSING: String = "processing"
