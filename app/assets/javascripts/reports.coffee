$(document).on 'turbolinks:load', ->
  $('#clear_all_default').on 'click', (e) ->
    $('#default input:checkbox').prop('checked', false);
