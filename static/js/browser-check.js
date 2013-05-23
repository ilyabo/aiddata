if (!(!!document.createElementNS && !!document.createElementNS('http://www.w3.org/2000/svg', "svg").createSVGRect)) {
  $body.append(
      '<div id="warning"><h2>Incompatible browser</h2>'+
      '<p>Unfortunately your browser does not support SVG which is required by this application.<br /><br />'+
      'We recommend to use <span class="recommendation"></span></p><div class="close">X</div></div>');

  if(navigator.userAgent.search(/Mac OS X/) !== -1) {
    $('#warning .recommendation').html('<a href="http://www.apple.com/safari/" target="_blank">Apple Safari</a>');
  }
  else {
    $('#warning .recommendation').html(
      '<a href="https://www.google.com/chrome" target="_blank">Google Chrome</a>' +
      ' or  '+
      '<a href="http://www.mozilla.org/firefox/" target="_blank">Firefox</a>'
      );
  }
  $('#warning .close').click(function(){
    $('#warning').fadeOut();
  });
}
