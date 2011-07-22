package com.etherpros.components
{
	import com.etherpros.controllers.*;
	import com.etherpros.events.JobEvent;
	import com.etherpros.model.*;
	
	import flash.display.*;
	import flash.events.*;
	import flash.geom.Point;
	
	import mx.collections.ArrayCollection;
	import mx.controls.Alert;
	import mx.controls.Label;
	import mx.core.UIComponent;
	import mx.graphics.GradientBase;
	
	import spark.components.Group;
	
	public class JobView extends Group
	{ 
		private const X_PADDING:Number = 8;
		
		private const LEFT:Number = 0;
		private const RIGHT:Number = 1;
		
		
		/** width and height of new empty sprites.
		 *  this usually corresponds to the width of a single day. **/
		private var defaultWidth:Number;
		private var defaultHeight:Number;
		
		/** X and Y position of first row added **/
		private var initialX:Number;
		private var initialY:Number;

		
		/** contains all the rounded corner sprites per week (a week is a row). **/
		private var spriteRows:ArrayCollection = new ArrayCollection();
						
		// DEPRECATED Previews and next Job bar for making a linked list
		private var _previousJobView:JobView;
		private var _nextJobView:JobView;
		
		private var _model:Job;
		
		/** Selected grid row during a resize operation **/
		private var dragTarget:JobSprite;
		
		/** Can either be LEFT or RIGHT.
		 *  Is used when resizing a component to determine how it is being resized. **/			
		private var dragDirection:Number;
		/** Limit used for the drag and drop functionallity, the limit is related with the grid with **/
		private var dragAndDropLimit:Number = -1;		
		private var originalWidth:Number = 0;		
		/** Used for determining the difference in mouse position when dragging. **/
		private var originalMousePos:Point;		
		private var mousePositionX:int = 0;			
		/** When set to false resize operations are disabled. **/
		private var dragValid:Boolean = true;
		
		// row, column position on calendar grid.
		public var pos:Point;
		
		// All JobViews are displayed based on a certain range of dates. 
		// These JobViews can be dragged from their left and right corners 
		// to extend or reduce the range of a particular job.
		//
		// When a particular JobView starts before or ends after the range
		// being viewed, then those sides are out of the users view and are
		// said to be "out of range".
		//
		// For example: 
		// If the user is currently viewing on the calendar the month of
		// July, but one of the jobs starts on JUNE 28 and ends on July 10,
		// since the job starts outside of the visible range, 
		// but still forms part of the range being viewed since it FINISHES inside that viewable range,
		// its "leftInRange" value will be false. 
		// (and the job will probably have leftDraggable set to false as well).
		public var leftInRange:Boolean = true;
		public var rightInRange:Boolean = true;
		
		// determines which sides can be dragged
		public var leftDraggable:Boolean = true;
		public var rightDraggable:Boolean = true;
				
		public function JobView(model:Job, width:Number=300, height:Number=100, initialX:Number=0, initialY:Number=0) {
			// initialize variables			
			this.model = model;		
			this.defaultWidth = width;
			this.defaultHeight = height;
			this.initialX = initialX;
			this.initialY = initialY;
			
			// if color hasn't been set already, assign a new random color.
			if (!this.model.jobColor) {								
				this.model.jobColor = Math.random() * 0xFFFFFF;
			}
						
			var sprite:JobSprite = createEmptySprite();
			sprite.x = initialX;
			sprite.y = initialY;			
		}
		
		/** Sets the first row of the grid to a given X and Y position **/
		public function position(x:int, y:int):void {
			var sprite:JobSprite = firstRow;
			sprite.x = x;
			sprite.y = y;
		}
		
		/** Creates empty sprite and adds the sprite to the spriteRows array.
		 *  This function is used when a jobview jumps to a new week row. **/
		public function createEmptySprite():JobSprite {			
			var sprite:JobSprite = new JobSprite(this.model.jobColor, this.model.contractor.FullName);
			sprite.width = defaultWidth;
			sprite.height = defaultHeight;
			sprite.addEventListener(MouseEvent.MOUSE_DOWN,mouseDown);
			// add sprite to sprite rows array.
			spriteRows.addItem(sprite);
			addElement(sprite);
			return sprite;
		}
					
		/** Causes job to 'snap' to a day based on it's x position and width **/
		private function snap():void {				
			dragTarget.x = Math.floor(dragTarget.x/CalendarController.DAY_WIDTH) * CalendarController.DAY_WIDTH;			
			dragTarget.width = Math.ceil(dragTarget.width/CalendarController.DAY_WIDTH)  * CalendarController.DAY_WIDTH;			
			// if new width surpasses calendar width, snap backwards
			if( (dragTarget.width + dragTarget.x) > CalendarController.CALENDAR_WIDTH) {				
				dragTarget.width = CalendarController.CALENDAR_WIDTH - dragTarget.x;
			}
		}
		
		/** Used for starting a drag operation when either 
		 *  the left or right corner of the component is clicked **/		
		private function mouseDown(event:Event):void {
			var target:JobSprite = event.currentTarget as JobSprite;			
			var index:int = findSpriteIndex(target);
			var mouseX:Number = target.mouseX;
			var mouseY:Number = target.mouseY;
			
			// left-drag. Only permit left drag if the first sprite row was grabbed.
			if(mouseX < 15 && index == 0 && leftDraggable) {
				dragDirection = LEFT;
				beginDrag(target);
			// right-drag. Only permit right drag if the last sprite row was grabbed.	
			}else if(mouseX > target.width-15 && index == spriteRows.length-1 && rightDraggable) {
				dragDirection = RIGHT;				
				beginDrag(target);
			} else { 				
				// no drag direction.
				dragDirection = -1;
			}
		}
		
		private function beginDrag(target:JobSprite):void {			
			dragTarget = target;
			
			// record position of mouse before drag to determine differences
			originalMousePos = new Point(stage.mouseX, stage.mouseY);
			
			// create event listener that listens for mouse movements to 
			// determine when to resize the component.
			stage.addEventListener(MouseEvent.MOUSE_MOVE, resize);
			stage.addEventListener(MouseEvent.MOUSE_UP, endDrag);
		}
		
		private function endDrag(event:Event=null):void {
			dragValid = true;			
			if ( stage != null ) {
				stage.removeEventListener(MouseEvent.MOUSE_MOVE, resize);				
			}
			
			stage.removeEventListener(MouseEvent.MOUSE_UP, endDrag);
		
			if(spriteRows.length > 0) {
				// After a drag-drop operation, snap the job to the correct day 
				snap();
				
				// dispatch event marking resize has finished!
				var resizedEvent:JobEvent = new JobEvent(JobEvent.JOB_RESIZED);
				resizedEvent.view = this;
				resizedEvent.model = model;
				dispatchEvent(resizedEvent);					
			}
			// define remove event
		}
				
		private function addRow():void {
			var jobEvent:JobEvent = new JobEvent(JobEvent.ADD_JOB_SPRITE);
			jobEvent.view = this;
			jobEvent.model = model;
			dispatchEvent(jobEvent);			
		}
		
		/** Resizes the width of the selected job row based on the change in mouse position from the drag. **/
		private function resize(event:Event=null):void {
			var target:JobSprite = dragTarget;
			
			// exit out of function if drag has been invalidated.			
			if(!dragValid) { return; }
			
			var mousePos:Point = new Point(this.stage.mouseX, this.stage.mouseY);			
			var widthChange:int = mousePos.x - originalMousePos.x; 
			mousePositionX  = 	mousePos.x;			
			if(dragDirection == LEFT) {
				// change width based on new difference between the ojobinal mouse
				// position recorded before drag and the new mouse position.
				target.width -= widthChange;	
				
				// if the direction of the drag is LEFT, then we must also offset the 
				// change in width through the x position.				
				target.x += widthChange;
			} else {				
				target.width += widthChange;				
			}				
			originalMousePos = mousePos;
			
			// if the width of the job row has surpassed that of our calendar
			// break the job into a new row.					
			if( (target.width + target.x) > CalendarController.CALENDAR_WIDTH) {				
				// reset width to be the same as the calendar width.
				target.width = CalendarController.CALENDAR_WIDTH - target.x;
				
				// dispatch new row created event.
				addRow();
				
				// When resizing a job, if the job jumps to a new
				// row when it is resized beyond its available width.
				// the current resize operation that is taking place
				// becomes no longer valid, since the job is now placed into a new row.
				// So we invalidate the current drag-drop operation to force the user
				// to start dragging from the new row.
				dragValid = false;
				
				// TODO: Throw row added event.
			}						
			// if the width of the job row is 0, remove row from array
			if(target.width <= 0) {
				// TODO: Throw destroy event.				
				// remove job row from rows array.
				var index:int = spriteRows.getItemIndex(target);
				// only remove sprite if it was found in the array
				if(index != -1) {
					spriteRows.removeItemAt(index);
				}
				// remove sprite row from stage
				removeElement(target);
				
				dragValid = false;
			}
		}
		
		public function paint(daySpan:int, startDayIndex:int):void {
			var numberOfRows:int = Math.ceil( (daySpan+startDayIndex)/Week.DAYS_BY_WEEK);
			// set the last sprite width to the remainder number of days
			if(numberOfRows > 1) {
				var remainder:int = daySpan - ( (numberOfRows-1) * Week.DAYS_BY_WEEK) + startDayIndex;
			} else {
				var remainder:int = daySpan; 
			}
			
			for(var i:int=1; i < numberOfRows; i++) {
				var sprite:JobSprite = spriteRows[i-1];
				// since new rows are added, all the previous rows must be max width.
				sprite.width = CalendarController.CALENDAR_WIDTH - sprite.x;
				addRow();
			}
						
			// in the last row
			lastRow.width = CalendarController.DAY_WIDTH * remainder;
		}		
		
		/** Redraws the graphics of the job. Used for updating the view
		 *  with changes to the width or height of the component **/
		public function draw(event:Event=null):void {			
			// loop through all sprites in sprites array
			// and redraw their graphics.
			for each(var sprite:JobSprite in spriteRows) {
				sprite.draw();		
			}
		}
		
		/** Searches for passed in sprite in the spriteRows
		 *  array and returns the corresponding index.
		 *  If the sprite is not found in the array, -1
		 *  is returned **/
		private function findSpriteIndex(sprite:JobSprite):int {
			var i:int = 0;
			for each(var currentSprite:JobSprite in spriteRows) {
				// match found
				if(sprite == currentSprite) {
					return i;
				}
				i++;
			}
			// if no matches found, return -1
			return -1;
		}
		
		public function destroy():void {
			// clean up event listeners.
			for each(var sprite:JobSprite in spriteRows) {
				sprite.removeEventListener(MouseEvent.MOUSE_DOWN,mouseDown);
			}
			
			//stage.removeEventListener(MouseEvent.MOUSE_MOVE,resize);
			this.removeAllElements();
		}
		
		
		// -------------------
		// Getters and Setters
		// -------------------
		public function get rowIndex():int {
			if(pos) {
				return pos.y;
			}
			return 0;
		}
		
		public function get columnIndex():int {
			if(pos) {
				return pos.x;			
			}
			
			return 0;
		}
		
		public function get endRow():int {
			return pos.y + numRows - 1;
		}
		
		public function get numRows():int {
			return spriteRows.length;
		}
		
		public function get firstRow():JobSprite {
			return spriteRows[0];
		}
		
		public function get lastRow():JobSprite {
			return spriteRows[spriteRows.length-1];
		}
		
		public function get nextJobView():JobView {
			return _nextJobView;
		}

		public function set nextJobView(value:JobView):void {
			_nextJobView = value;
		}

		public function get previousJobView():JobView {
			return _previousJobView;
		}

		public function set previousJobView(value:JobView):void {
			_previousJobView = value;
		}
		
		/** Day range that the job covers. **/
		public function get model():Job
		{
			return _model;
		}

		/**
		 * @private
		 */
		public function set model(value:Job):void
		{
			_model = value;
		}

	}
}