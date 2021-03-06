(function($) {

var t = new Test.Visual();

t.plan(1);

t.runAsync([
    function() {
        t.open_iframe(
            "/admin/index.cgi?how_do_i_make_a_new_page",
            t.nextStep()
        );
    },

    function() {
        // Scroll to wherever the attachment widget is
        t.scrollTo(t.$("#st-attachment-listing").offset().top - 50);

        var hoverText = t.$("#st-attachment-listing li:eq(0) a:eq(0)").attr("title");
        t.like(hoverText, /Uploaded by (.+) on (.+)\.\d+(K|M| bytes)/, "Attachment hover text contains uploader, date and size info.");

        t.endAsync();
    }
]);

})(jQuery);
