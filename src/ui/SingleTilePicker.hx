package ui;

class SingleTilePicker {
	static var SCROLL_MEMORY : Map<Int, { x:Float, y:Float, zoom:Float }> = new Map();

	var tilesetDef : led.def.TilesetDef;

	var jDoc(get,never) : js.jquery.JQuery; inline function get_jDoc() return new J(js.Browser.document);

	var jPicker : js.jquery.JQuery;
	var jAtlas : js.jquery.JQuery;

	var zoom(default,set) : Float;
	var jCursor : js.jquery.JQuery;
	var jSelection : js.jquery.JQuery;

	var dragStart : Null<{ bt:Int, pageX:Float, pageY:Float }>;

	var scrollX(default,set) : Float;
	var scrollY(default,set) : Float;

	public function new(target:js.jquery.JQuery, td:led.def.TilesetDef) {
		tilesetDef = td;

		// Create picker elements
		jPicker = new J('<div class="tilesetPicker"/>');
		jPicker.appendTo(target);

		jAtlas = new J('<div class="wrapper"/>');
		jAtlas.appendTo(jPicker);

		jCursor = new J('<div class="cursorsWrapper"/>');
		jCursor.prependTo(jAtlas);

		jSelection = new J('<div class="selectionsWrapper"/>');
		jSelection.prependTo(jAtlas);

		var jImg = new J( tilesetDef.createAtlasHtmlImage() );
		jImg.appendTo(jAtlas);
		jImg.addClass("atlas");

		// Init events
		jPicker.mousedown( function(ev) {
			ev.preventDefault();
			onPickerMouseDown(ev);
			jDoc
				.off(".pickerDragEvent")
				.on("mouseup.pickerDragEvent", onDocMouseUp)
				.on("mousemove.pickerDragEvent", onDocMouseMove);
		});

		jPicker.get(0).onwheel = onPickerMouseWheel;
		jPicker.mousemove( onPickerMouseMove );

		loadScrollPos();
	}


	function loadScrollPos() {
		var mem = SCROLL_MEMORY.get(tilesetDef.uid);
		if( mem!=null ) {
			scrollX = mem.x;
			scrollY = mem.y;
			zoom = mem.zoom;
		}
		else {
			scrollX = 0;
			scrollY = 0;
			zoom = 3;
		}
	}

	function saveScrollPos() {
		SCROLL_MEMORY.set(tilesetDef.uid, { x:scrollX, y:scrollY, zoom:zoom });
	}

	function set_zoom(v) {
		zoom = M.fclamp(v, 0.5, 6);
		jAtlas.css("zoom",zoom);
		saveScrollPos();
		return zoom;
	}

	inline function set_scrollX(v:Float) {
		scrollX = v;
		jAtlas.css("margin-left",-scrollX);
		saveScrollPos();
		return v;
	}

	inline function set_scrollY(v:Float) {
		scrollY = v;
		jAtlas.css("margin-top",-scrollY);
		saveScrollPos();
		return v;
	}

	inline function pageXtoLocal(v:Float) return M.round( ( v - jPicker.offset().left ) / zoom + scrollX );
	inline function pageYtoLocal(v:Float) return M.round( ( v - jPicker.offset().top ) / zoom + scrollY );


	function createCursor(sel:led.LedTypes.TilesetSelection, ?subClass:String, ?cWid:Int, ?cHei:Int) {
		var wrapper = new J("<div/>");
		var idsMap = new Map();
		for(tileId in sel.ids)
			idsMap.set(tileId,true);
		inline function hasCursorAt(cx:Int,cy:Int) {
			return idsMap.exists( tilesetDef.getTileId(cx,cy) );
		}

		var showIndividuals = sel.mode==Random;

		for(tileId in sel.ids) {
			var x = tilesetDef.getTileSourceX(tileId);
			var y = tilesetDef.getTileSourceY(tileId);
			var cx = tilesetDef.getTileCx(tileId);
			var cy = tilesetDef.getTileCy(tileId);

			var e = new J('<div class="tileCursor"/>');
			e.appendTo(wrapper);
			if( subClass!=null )
				e.addClass(subClass);

			if( showIndividuals )
				e.addClass("randomMode");
			else {
				e.addClass("stampMode");
				if( !hasCursorAt(cx-1,cy) ) e.addClass("left");
				if( !hasCursorAt(cx+1,cy) ) e.addClass("right");
				if( !hasCursorAt(cx,cy-1) ) e.addClass("top");
				if( !hasCursorAt(cx,cy+1) ) e.addClass("bottom");
			}

			e.css("left", x+"px");
			e.css("top", y+"px");
			var grid = tilesetDef.tileGridSize;
			e.css("width", ( cWid!=null ? cWid*grid : tilesetDef.tileGridSize )+"px");
			e.css("height", ( cHei!=null ? cHei*grid : tilesetDef.tileGridSize )+"px");
		}

		return wrapper;
	}



	var _lastRect = null;
	function updateCursor(pageX:Float, pageY:Float, force=false) {
		if( isScrolling() || Editor.ME.isKeyDown(K.SPACE) ) {
			jCursor.hide();
			return;
		}

		// Editor.ME.debug(pageX+","+pageY+" => "+pageXtoLocal(pageX)+","+pageYtoLocal(pageY));
		// Editor.ME.debug("scroll="+scrollX+","+scrollY, true);
		// Editor.ME.debug("pickerSize="+jPicker.innerWidth()+"x"+jPicker.innerHeight(), true);
		// Editor.ME.debug("img="+img.innerWidth()+"x"+img.innerHeight(), true);

		var r = getCursorRect(pageX, pageY);

		// Avoid re-render if it's the same rect
		if( !force && _lastRect!=null && r.cx==_lastRect.cx && r.cy==_lastRect.cy && r.wid==_lastRect.wid && r.hei==_lastRect.hei )
			return;

		var tileId = tilesetDef.getTileId(r.cx,r.cy);
		jCursor.empty();
		jCursor.show();

		_lastRect = r;
	}

	function scroll(newPageX:Float, newPageY:Float) {
		var spd = 1.;

		scrollX -= ( newPageX - dragStart.pageX ) / zoom * spd;
		dragStart.pageX = newPageX;

		scrollY -= ( newPageY - dragStart.pageY ) / zoom * spd;
		dragStart.pageY = newPageY;
	}

	inline function isScrolling() {
		return dragStart!=null && ( dragStart.bt==1 || Editor.ME.isKeyDown(K.SPACE) );
	}

	function onDocMouseMove(ev:js.jquery.Event) {
		updateCursor(ev.pageX, ev.pageY);

		if( isScrolling() )
			scroll(ev.pageX, ev.pageY);
	}

	function onDocMouseUp(ev:js.jquery.Event) {
		jDoc.off(".pickerDragEvent");

		// Apply selection
		if( dragStart!=null && !isScrolling() ) {
			var r = getCursorRect(ev.pageX, ev.pageY);
			var addToSelection = dragStart.bt!=2;
			if( r.wid==1 && r.hei==1 ) {
				applySelection([ tilesetDef.getTileId(r.cx,r.cy) ], addToSelection);
			}
			else {
				var tileIds = [];
				for(cx in r.cx...r.cx+r.wid)
				for(cy in r.cy...r.cy+r.hei)
					tileIds.push( tilesetDef.getTileId(cx,cy) );
				applySelection(tileIds, addToSelection);
			}
		}

		dragStart = null;
		updateCursor(ev.pageX, ev.pageY, true);
	}

	function applySelection(selIds:Array<Int>, add:Bool) {
		// TODO
	}


	function onPickerMouseWheel(ev:js.html.WheelEvent) {
		if( ev.deltaY!=0 ) {
			ev.preventDefault();
			var oldLocalX = pageXtoLocal(ev.pageX);
			var oldLocalY = pageYtoLocal(ev.pageY);

			zoom += -ev.deltaY*0.001 * zoom;

			var newLocalX = pageXtoLocal(ev.pageX);
			var newLocalY = pageYtoLocal(ev.pageY);
			scrollX += ( oldLocalX - newLocalX );
			scrollY += ( oldLocalY - newLocalY );
		}
	}

	function onPickerMouseDown(ev:js.jquery.Event) {
		dragStart = {
			bt: ev.button,
			pageX: ev.pageX,
			pageY: ev.pageY,
		}

		// Block context menu
		if( ev.button==2 )
			jDoc.on("contextmenu.pickerCtxCatcher", function(ev) {
				ev.preventDefault();
				jDoc.off(".pickerCtxCatcher");
			});
	}

	function onPickerMouseMove(ev:js.jquery.Event) {
		updateCursor(ev.pageX, ev.pageY);
	}

	function getCursorRect(pageX:Float, pageY:Float) {
		var localX = pageXtoLocal(pageX);
		var localY = pageYtoLocal(pageY);

		var grid = tilesetDef.tileGridSize;
		var cx = M.iclamp( Std.int( localX / grid ), 0, tilesetDef.cWid-1 );
		var cy = M.iclamp( Std.int( localY / grid ), 0, tilesetDef.cHei-1 );

		if( dragStart==null )
			return {
				cx: cx,
				cy: cy,
				wid: 1,
				hei: 1,
			}
		else {
			var startCx = M.iclamp( Std.int( pageXtoLocal(dragStart.pageX) / grid ), 0, tilesetDef.cWid-1 );
			var startCy = M.iclamp( Std.int( pageYtoLocal(dragStart.pageY) / grid ), 0, tilesetDef.cHei-1 );
			return {
				cx: M.imin(cx,startCx),
				cy: M.imin(cy,startCy),
				wid: M.iabs(cx-startCx) + 1,
				hei: M.iabs(cy-startCy) + 1,
			}
		}
	}
}