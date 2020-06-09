worker_processes 2
pid "/tmp/dsd.pid"
preload_app false
Rainbows! {
	use :ThreadPool
	worker_connections 100
}
