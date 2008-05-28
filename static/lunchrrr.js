function change_time(time, diff) {
  minutes = parseInt(time.split(':')[0]) * 60 + parseInt(time.split(':')[1]);
  minutes = minutes + parseInt(diff);
  hours = parseInt(minutes / 60);
  minutes = minutes % 60;
  if (minutes == 0) { minutes = "00" };
  return hours + ":" + minutes;
}

$(function() {
    $('input#time')
      .before('<input  id=\'earlier\' type=\'submit\' value=\'-\' />')
      .after ('<input id=\'later\' type=\'submit\' value=\'+\' />');

    $('#earlier').bind('click', function() {
                         $('#time').val(change_time($('#time').val(), -30));
                         return false;
                       });
    $('#later').bind('click', function() {
                         $('#time').val(change_time($('#time').val(), 30));
                         return false;
                       });
});
