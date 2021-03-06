var t = new Test.Visual();

t.plan(2);

var original = t.gensym();
var incipient = t.gensym();

t.runAsync([
    function() {
        t.put_page({
            workspace: 'admin',
            page_name: original,
            content: "[" + incipient + "]\n",
            callback: t.nextStep()
        });
    },

    function() {
        t.open_iframe(
            "/lite/page/admin/" + original,
            t.nextStep()
        );
    },

    function() { 
        t.open_iframe(
            "/lite/page/admin/" + $('a.incipient', t.doc).attr('href'),
            t.nextStep()
        );
    },

    function() { 
        $('#edit_textarea', t.doc).val('fnord');
        $('form', t.doc).submit();

        t.open_iframe(
            "/admin/?" + incipient,
            t.nextStep()
        );
    },

    function() { 
        t.is(
            t.$('#st-page-titletext').text().replace(/\s/g, ''),
            incipient,
            "Page name for incipient pages created from /lite/ stays the same in full view"
        );

        t.is(
            t.$('#st-page-content').text().replace(/\s/g, ''),
            'fnord',
            "Page text for incipient pages created from /lite/ stays the same in full view"
        );

        t.callNextStep();
    },

    function() { 
        t.endAsync();
    }
]);
