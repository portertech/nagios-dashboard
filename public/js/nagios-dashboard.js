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
        +'</td><td>'+data[msg]['plugin_output']+'<div style="display: none;">'
        +'<div style="width:400px;height:100px;overflow:auto;">'
        +
        +'</div></div>'
        +'</td><td>'+last_time_ok.toLocaleString()
        +'</td><td>'+last_check.toLocaleString()+'</td></tr>');
      
      $("#messages > tr:last").click(function() {
        $.fancybox({
          'padding': 5,
          'content': '<strong>Long Plugin Output: </strong><pre>'
            +data[msg]['long_plugin_output']+'</pre><br />'
            +'<strong>Performance Data: </strong><pre>'+data[msg]['performance_data']+'</pre><br />'
            +'<strong>Check Command: </strong><pre>'+data[msg]['check_command']+'</pre><br />'
            +'<div id="attributes"><a href="#" id="get-node-attributes">Get Node Attributes</a></div>',
	      'title': data[msg]['host_name'],
	      'transitionIn': 'elastic',
	      'transitionOut': 'elastic'
	    });
      });
      $("#get-node-attributes").click(function() {
        $.getJSON('node/'+data[msg]['host_name'], function(attributes) {
          $('#attributes').html("<strong>Instance ID: </strong><pre>"+attributes.name+"</pre><br /><strong>Public Hostname: </strong><pre>"+attributes.public_hostname+"</pre>");
        });
      });
    };
  };
  ws.onclose = function() { debug("socket closed"); };
  ws.onopen = function() {
    debug("connected...");
  };
});
