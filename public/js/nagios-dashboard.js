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
      var last_time_ok = new Date(data[msg]['last_time_ok'] * 1000);
      var last_check = new Date(data[msg]['last_check'] * 1000);
      $("#messages").append('<tr class="'+status+'"><td>'+data[msg]['host_name']
        +'</td><td>'+data[msg]['plugin_output']+'</td><td>'+last_time_ok.toLocaleString()
        +'</td><td>'+last_check.toLocaleString()+'</td></tr>');
    };
  };
  ws.onclose = function() { debug("socket closed"); };
  ws.onopen = function() {
    debug("connected...");
  };
});
