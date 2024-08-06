---
layout: wasteworks
title: What is WasteWorks
order: 1
user-guide: true
category: user-guide
---

<style>
svg { max-width: 100%; height: auto; }
</style>

# Container picture generator

This can be used to test/pick colours to use as WasteWorks container icons on a bin day page.

<div style="display:flex; gap: 1em; flex: 1">
<div style="flex: 1">

<h2>Sack</h2>

<p><label>Sack colour: <input type="color" value='#333333' name="sack-colour" data-picture='svgsack' data-style='--primary-color'></label></p>

<svg class="svg-wrapper" style="--primary-color: #333333" id="svgsack" height=300>
<use href="/ww-manual/containers.svg#sack"></use>
</svg>

</div>
<div style="flex: 1">

<h2>Sack, with stripe</h2>

<p><label>Stripe colour: <input type="color" value='#4f4cf0' name="stripe-colour" data-picture='svgstripe' data-style="--primary-color"></label></p>

<svg class="svg-wrapper" style="--primary-color: #4f4cf0" id="svgstripe" height=300>
<use href="/ww-manual/containers.svg#sack-stripe"></use>
</svg>

</div>
</div>

<div style="display:flex; gap: 1em;">
<div style="flex: 1">

<h2>Wheelie bin</h2>

<p>
<label>Bin colour: <input value='#767472' type="color" name="bin-colour" data-picture='svgwheelie' data-style="--primary-color"></label>
<label>Lid colour: <input value='#8b5e3d' type="color" name="lid-colour" data-picture='svgwheelie' data-style="--lid-color"></label>
<label>Recycling logo: <input type="checkbox" name="recycling" data-picture='svgwheelie' data-style="--recycling-logo"></label>
</p>

<svg class="svg-wrapper" style="--primary-color: #767472; --lid-color: #8b5e3d" id="svgwheelie" height=300>
<use href="/ww-manual/containers.svg#wheelie"></use>
</svg>

</div>
<div style="flex: 1">

<h2>Communal bin</h2>

<p>
<label>Bin colour: <input value='#767472' type="color" name="bin-colour" data-picture='svgcommunal' data-style="--primary-color"></label>
<label>Lid colour: <input value='#41b38b' type="color" name="lid-colour" data-picture='svgcommunal' data-style="--lid-color"></label>
<label>Recycling logo: <input type="checkbox" name="recycling" data-picture='svgcommunal' data-style="--recycling-logo"></label>
</p>

<svg class="svg-wrapper" style="--primary-color: #767472; --lid-color: #41b38b" id="svgcommunal" height=300>
<use href="/ww-manual/containers.svg#communal"></use>
</svg>

</div>
</div>

## Box

<label>Box colour: <input value='#00a6d2' type="color" name="box-colour" data-picture='svgbox' data-style="--primary-color"></label>
<label>Recycling logo: <input checked type="checkbox" name="recycling" data-picture='svgbox' data-style="--recycling-logo"></label>

<svg class="svg-wrapper" style="--recycling-logo: 1; --primary-color: #00a6d2;" id="svgbox" height=150>
<use href="/ww-manual/containers.svg#box"></use>
</svg>

<script>
[].forEach.call(document.getElementsByTagName('input'), function(el) {
    el.addEventListener('input', function() {
        var svg = document.getElementById(this.dataset.picture).style;
        if (this.name == 'recycling') {
            svg.setProperty("--recycling-logo", this.checked ? 1 : 0);
        } else {
            svg.setProperty(this.dataset.style, this.value);
        }
    });
});
</script>
