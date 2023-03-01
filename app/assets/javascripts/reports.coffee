$(document).on 'turbolinks:load', ->
  $('#clear_all_default').on 'click', (e) ->
    $('#default input:checkbox').prop('checked', false);

  $(".clickable-row").on 'click', () ->
    window.location = $(this).data("href");
