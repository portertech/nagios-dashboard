$(document).ready(function(){
	function debug(str){ $("#debug").append("<p>" +  str); };
		ws = new WebSocket("ws://" + location.hostname + ":9000");
		ws.onmessage = function(evt) {
			$("#messages").empty();
			data = JSON.parse(evt.data);

			for(var msg in data) {
				var status = '';
				if(data[msg]['status'] == 'CRITICAL') {
					status = "Critical";
				} else if (data[msg]['status'] == 'WARNING') {
					status = "Warning";
				}
				$("#messages").append('<tr class="'+status+'"><td>'+data[msg]['host_name']
					+'</td><td>'+data[msg]['plugin_output']+'</td><td>'+data[msg]['last_time_ok']
					+'</td><td>'+data[msg]['last_check']+'</td></tr>');
			};
		};
		ws.onclose = function() { debug("socket closed"); };
		ws.onopen = function() {
		debug("connected...");
	};
});
