$(document).ready(function(){
  function get_chef_attributes(hostname) {
    $.getJSON('node/'+hostname, function(attributes) {
      var roles = '';
      $.each(attributes['automatic']['roles'], function() {
        roles += this + ' ';
      });
      $('.chef_attributes').html(
        '<strong>Environment: </strong><pre>'+attributes['override']['app_environment']+'</pre><br />'
        +'<strong>Node Name: </strong><pre>'+attributes['name']+'</pre><br />'
        +'<strong>Public IP: </strong><pre>'+attributes['automatic']['ec2']['public_ipv4']+'</pre><br />'
        +'<strong>Roles: </strong><pre>'+roles+'</pre>'
      );
    });
  }
  ws = new WebSocket("ws://" + location.hostname + ":9000");
  ws.onmessage = function(evt) {
    $("#messages").empty();
    $("#popups_container").empty();
    data = JSON.parse(evt.data);
    for(var msg in data) {
      var status = '';
      if(data[msg]['status'] == 'CRITICAL') {
        status = "Critical";
      } else {
        status = "Warning";
      }
      var last_time_ok = new Date(data[msg]['last_time_ok'] * 1000);
      var last_check = new Date(data[msg]['last_check'] * 1000);
      $("#messages").append('<tr class="'+status+'" id="link_'+msg+'" href="#popup_'+msg+'"><td>'+data[msg]['host_name']
        +'</td><td>'+data[msg]['plugin_output']+'<div style="display: none;">'
        +'<div style="width:400px;height:100px;overflow:auto;">'
        +'</div></div>'
        +'</td><td>'+last_time_ok.toLocaleString()
        +'</td><td>'+last_check.toLocaleString()+'</td></tr>');
      var plugin_output = '';
      if (data[msg]['long_plugin_output'] != '') {
        plugin_output = data[msg]['long_plugin_output'];
      } else {
        plugin_output = data[msg]['plugin_output'];
      }
      $("#popups_container").append('<div id="popup_'+msg+'">'
        +'<strong>Check Command: </strong><pre>'+data[msg]['check_command']+'</pre><br />'
        +'<strong>Plugin Output: </strong><pre>'+plugin_output+'</pre><br />'
        +'<div class="chef_attributes">Querying Chef ...</div>'
        +'</div>');
      $("#link_"+msg).fancybox({
        'autoDimensions' : false,
        'width'          : 700,
        'height'         : 420,
        'padding'        : 5,
        'title'          : data[msg]['host_name'],
        'transitionIn'   : 'fade',
        'transitionOut'  : 'fade',
        'onComplete'     : function() { get_chef_attributes($("#fancybox-title-float-main").html()); },
        'onClosed'       : function() { $('.chef_attributes').html('Querying Chef ...'); }
      });
    };
  };
});
