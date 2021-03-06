###
  * Copyright (c) 2011, iSENSE Project. All rights reserved.
  *
  * Redistribution and use in source and binary forms, with or without
  * modification, are permitted provided that the following conditions are met:
  *
  * Redistributions of source code must retain the above copyright notice, this
  * list of conditions and the following disclaimer. Redistributions in binary
  * form must reproduce the above copyright notice, this list of conditions and
  * the following disclaimer in the documentation and/or other materials
  * provided with the distribution. Neither the name of the University of
  * Massachusetts Lowell nor the names of its contributors may be used to
  * endorse or promote products derived from this software without specific
  * prior written permission.
  *
  * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
  * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
  * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
  * ARE DISCLAIMED. IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE FOR
  * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
  * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
  * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
  * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
  * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
  * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH
  * DAMAGE.
  *
###
$ ->
  if namespace.controller is 'visualizations' and
  namespace.action in ['displayVis', 'embedVis', 'show']

    class window.Scatter extends BaseHighVis
      ###
      Initialize constants for scatter display mode.
      ###
      constructor: (@canvas) ->
        super(@canvas)

        @SYMBOLS_LINES_MODE = 3
        @LINES_MODE = 2
        @SYMBOLS_MODE = 1

        @MAX_SERIES_SIZE = 600
        @INITIAL_GRID_SIZE = 150

        @xGridSize = @yGridSize = @INITIAL_GRID_SIZE

        @useSetAxis = true
        @isTimeline = null
        # Used for data reduction triggering
        @updateOnZoom = true

        @configs.mode ?= @SYMBOLS_MODE

        # @configs.xAxisId ?= -1
        @configs.xAxis ?= data.normalFields[0]
        # TODO write a migration to nuke @configs.yAxis
        @configs.advancedTooltips ?= 0

        # Do the cool existential operator thing
        @configs.savedRegressions ?= []

        @configs.xBounds ?=
          dataMax: undefined
          dataMin: undefined
          max: undefined
          min: undefined
          userMax: undefined
          userMin: undefined

        @configs.yBounds ?=
          dataMax: undefined
          dataMin: undefined
          max: undefined
          min: undefined
          userMax: undefined
          userMin: undefined

        @configs.fullDetail ?= 0

      start: (animate = true) ->
        @configs.xAxisId ?= data.fields[@configs.xAxis].fieldID
        # Reset the xAxis in case a new field was added or fields were reordered
        if not @useSetAxis? then @configs.xAxis = data.timeFields[0]
        else if @configs.xAxisId == -1 then @configs.xAxis = 0
        else
          fieldIds = for field in data.fields
            field.fieldID
          @configs.xAxis = fieldIds.indexOf(@configs.xAxisId)

        super(animate)

      storeXBounds: (bounds) ->
        @configs.xBounds = bounds

      storeYBounds: (bounds) ->
        @configs.yBounds = bounds

      ###
      Build up the chart options specific to scatter chart
      The only complex thing here is the html-formatted tooltip.
      ###
      buildOptions: (animate = true) ->
        super(animate)

        self = this
        canvas = @canvas
        $.extend true, @chartOptions,
          chart:
            type: if @configs.mode is @LINES_MODE then "line" else "scatter"
            zoomType: "xy"
            resetZoomButton:
              theme:
                display: "none"
          plotOptions:
            scatter:
              animation: false
              allowPointSelect: true
              marker:
                states:
                  hover:
                    lineColor:'#000'
              point:
                events:
                  mouseOver: () ->
                    # Push elements to bottom to draw over others in series
                    ele = $(@.graphic.element)
                    root = ele.parent()
                    root.append ele
                  select: () ->
                    if globals.annotationSet?
                      AnnotationSet.deselect()
                    globals.selectedDataSetId = globals.getDataSetId(@.datapoint[1])
                    globals.selectedPointId = @.datapoint[0]
                    globals.selectedPointX = @x
                    globals.selectedPointY = @y
                    globals.selectedPointField = data.fields.findIndex (elt) => elt.fieldName is @series.name.field
                    $('#disable-point-button').prop("disabled", false)
                    # Change button to edit if applicable
                    if (globals.annotationSet isnt null) and \
                       (globals.annotationSet.hasAnnotationAt globals.selectedDataSetId, globals.selectedPointId, \
                                                              canvas, globals.selectedPointField)
                      toggleAnnotationButton("comment-edit")
                    # Else make it add
                    else
                      toggleAnnotationButton("comment-add")
                  unselect: () ->
                    # See if another point has been selected
                    p = @series.chart.getSelectedPoints()
                    if (p.length > 0) and (p[0].x == @x) and (p[0].y == @y)
                      if (Annotation.selectedAnnotation is false)
                        toggleAnnotationButton("comment-add")
                      $('#disable-point-button').prop("disabled", true)

          groupBy = ''
          $('#groupSelector').find('option').each (i,j) ->
            if $(j).is(':selected')
              groupBy = $(j).text()
          title:
            text: ""
          tooltip:
            formatter: ->
              if @series.name.regression?
                str  = @series.name.regression.tooltip
              else
                if self.configs.advancedTooltips
                  str  = "<div style='width:100%;text-align:center;color:#{@series.color};'> "
                  str += "#{@series.name.group}</div><br>"
                  str += "<table>"

                  for field, fieldIndex in data.fields when @point.datapoint[fieldIndex] isnt null
                    dat = if (Number field.typeID) is data.types.TIME
                      (globals.dateFormatter @point.datapoint[fieldIndex])
                    else
                      @point.datapoint[fieldIndex]
                    
                    if field.fieldName isnt 'Number Fields' and
                    field.fieldName isnt 'Time Period' and
                    field.fieldName isnt 'Combined Data Sets'
                      str += "<tr><td>#{field.fieldName}</td>"
                      str += "<td><strong>#{dat}</strong></td></tr>"

                  str += "</table>"
                else
                  str  = "<div style='width:100%;text-align:center;color:#{@series.color};'> "
                  str += "#{@series.name.group}</div><br>"
                  str += "<table>"
                  str += "<tr><td>#{@series.xAxis.options.title.text}:</td><td><strong>#{@x}"
                  str += "</strong></td></tr>"
                  index = data.fields.map((y) -> y.fieldName).indexOf(@series.name.field)
                  str += "<tr><td>#{@series.name.field}:</td><td><strong>#{@y} \
                  #{fieldUnit(data.fields[index], false)}</strong></td></tr>"
                  str += "</table>"
            useHTML: true
            # Turning 'shared' on when in scatter fixes Issue #2322.
            # Note that 'shared' doesn't function in scatter mode, but somehow fixes our issue.
            shared: if (@configs.mode is @LINES_MODE or @configs.savedRegressions.length > 0) then false else true
            hideDelay: 0

          xAxis: [{
            alignTicks: false
            type: 'linear'
            gridLineWidth: 1
            minorTickInterval: 'auto'
            minRange: 1e-10
            }]
          yAxis:
            startOnTick: false
            endOnTick: false
            minRange: 1e-10
            type: if globals.configs.logY then 'logarithmic' else 'linear'
            events:
              afterSetExtremes: (e) =>
                @storeXBounds @chart.xAxis[0].getExtremes()
                @storeYBounds @chart.yAxis[0].getExtremes()

                ###
                If we actually zoomed, we want to update so the data reduction
                can trigger. Otherwise this zoom was triggered by an update, so
                don't recurse!
                ###
                if @updateOnZoom then @delayedUpdate()
                else @updateOnZoom = true

      ###
      Build the dummy series for the legend.
      ###
      buildLegendSeries: ->
        count = -1
        for f, i in data.fields when i in data.normalFields
          count += 1
          options =
            legendIndex: i
            data: []
            color: '#000'
            showInLegend: i in globals.configs.fieldSelection
            name: f.fieldName

          switch
            when @configs.mode is @SYMBOLS_LINES_MODE
              options.marker =
                symbol: globals.symbols[count % globals.symbols.length]
              options.lineWidth = 2

            when @configs.mode is @SYMBOLS_MODE
              options.marker =
                symbol: globals.symbols[count % globals.symbols.length]
              options.lineWidth = 0

            when @configs.mode is @LINES_MODE
              options.marker =
                symbol: 'blank'
              options.dashStyle = globals.dashes[count % globals.dashes.length]
              options.lineWidth = 2

          options

      ###
      Call control drawing methods in order of apperance
      ###
      drawControls: ->
        super()
        # Remove group by number fields, only for pie chart
        groups = $.extend(true, [], data.textFields)
        groups.splice(data.NUMBER_FIELDS_FIELD - 1, 1)
        # Remove Group By Time Period if there is no time data
        if data.hasTimeData is false or data.timeType == data.GEO_TIME
          groups.splice(data.TIME_PERIOD_FIELD - 2, 1)
        @drawGroupControls(groups)
        @drawXAxisControls()
        @drawYAxisControls(globals.configs.fieldSelection,
          data.normalFields.slice(1), false)
        @drawToolControls()
        @drawClippingControls()
        @drawRegressionControls()
        @drawSaveControls()
        @drawAnnotationControls()
        $('[data-toggle="tooltip"]').tooltip();

      ###
      Update the chart by removing all current series and recreating them
      ###
      update: () ->
        # Remove all series and draw legend
        super()

        @configs.xAxisId = data.fields[@configs.xAxis].fieldID

        title =
          text: fieldTitle data.fields[@configs.xAxis]
        @chart.xAxis[0].setTitle title, false

        dp = globals.getData(true, globals.configs.activeFilters)

        # Helper Function to modify the date based on period option on Timeline
        # Dates are normalized to 1990 so that when they are graphed, dates fall
        # on the right point, e.g. if the period option is set to Yearly, then
        # October 14 2016 and October 14 1994 will fall on the same x-value on the Timeline.
        modifyDate = (date) ->
          switch
            when globals.configs.periodMode is 'yearly'
              new Date(1990, date.getMonth(), date.getDate(), date.getHours(),
                       date.getMinutes(), date.getSeconds(), date.getMilliseconds()).getTime()
            when globals.configs.periodMode is 'monthly'
              new Date(1990, 0, date.getDate(), date.getHours(), date.getMinutes(),
                       date.getSeconds(), date.getMilliseconds()).getTime()
            when globals.configs.periodMode is 'weekly'
              # Jan 1 1989 is a Sunday
              new Date(1989, 0, date.getDay() + 1, date.getHours(), date.getMinutes(),
                       date.getSeconds(), date.getMilliseconds()).getTime()
            when globals.configs.periodMode is 'daily'
              new Date(1990, 0, 1, date.getHours(), date.getMinutes(), date.getSeconds(),
                       date.getMilliseconds()).getTime()
            when globals.configs.periodMode is 'hourly'
              new Date(1990, 0, 1, 0, date.getMinutes(), date.getSeconds(), date.getMilliseconds()).getTime()

        # Compute max bounds if there is no user zoom
        if not @isZoomLocked()
          @configs.yBounds.min = @configs.xBounds.min =  Number.MAX_VALUE
          @configs.yBounds.max = @configs.xBounds.max = -Number.MAX_VALUE

          for fi in data.normalFields when fi in globals.configs.fieldSelection
            for g, gi in data.groups when gi in data.groupSelection
              @configs.yBounds.min = Math.min(@configs.yBounds.min,
                data.getMin(fi, gi, dp))
              @configs.yBounds.max = Math.max(@configs.yBounds.max,
                data.getMax(fi, gi, dp))
              @configs.xBounds.min = Math.min(@configs.xBounds.min,
                data.getMin(@configs.xAxis, gi, dp))
              @configs.xBounds.max = Math.max(@configs.xBounds.max,
                data.getMax(@configs.xAxis, gi, dp))


        # Calculate grid spacing for data reduction
        width = $('#' + @canvas).innerWidth()
        height = $('#' + @canvas).innerHeight()

        @xGridSize = @yGridSize = @INITIAL_GRID_SIZE

        if width > height
          @yGridSize = Math.round (height / width * @INITIAL_GRID_SIZE)
        else
          @xGridSize = Math.round (width / height * @INITIAL_GRID_SIZE)

        # Clear all annotations
        toggleAnnotationButton("comment-add")
        $('.highcharts-annotation').remove()
        if globals.annotationSet?
          for elt in globals.annotationSet.list
            if elt.callout
              elt.enabled = false

        # Draw series
        fs = globals.configs.fieldSelection
        for fi, si in data.normalFields when fi in fs
          for g, gi in data.groups when gi in data.groupSelection
            dat =
              if not @configs.fullDetail
                sel = data.xySelector(@configs.xAxis, fi, gi, dp)
                globals.dataReduce(sel, @configs.xBounds, @configs.yBounds,
                  @xGridSize, @yGridSize, @MAX_SERIES_SIZE)
              else
                data.xySelector(@configs.xAxis, fi, gi, dp)
            
            # For Timeline Period option:
            # There was a bug causing the lines connecting points to wrap around from
            # the right edge to the left (ex: http://i.imgur.com/SIzP03P.png). This block
            # fixes it by splitting the data into different series based on the range
            # the point falls in (ex fixed: http://i.imgur.com/NDIrq8i.png).
            datArray = new Array
            if @isTimeline and globals.configs.isPeriod is true and data.timeType == data.NORM_TIME
              currentPeriod = null
              for point in dat
                newDate = new Date(point.x)
                thisPeriod = globals.getCurrentPeriod(newDate)
                if currentPeriod is null
                  datArray.push(new Array)
                  currentPeriod = thisPeriod
                if thisPeriod != currentPeriod
                  currentPeriod = thisPeriod
                  datArray.push(new Array)
                point.x = modifyDate(newDate)
                datArray[datArray.length - 1].push(point)
            else
              # if not using the period option, don't worry about the above.
              datArray.push(dat)

            mode = @configs.mode
            if dat.length < 2 and @configs.mode is @LINES_MODE
              mode = @SYMBOLS_LINES_MODE
            
            # loop through all the series and add them to the chart
            for series in datArray
              options =
                data: series
                showInLegend: false
                color: globals.getColor(gi)
                name:
                  group: data.groups[gi]
                  field: data.fields[fi].fieldName
              if series.length < 2 and @configs.mode is @LINES_MODE
                options.marker =
                  symbol: globals.symbols[si % globals.symbols.length]
                options.lineWidth = 2
              else
                switch
                  when mode is @SYMBOLS_LINES_MODE
                    options.marker =
                      symbol: globals.symbols[si % globals.symbols.length]
                    options.lineWidth = 2

                  when mode is @SYMBOLS_MODE
                    options.marker =
                      symbol: globals.symbols[si % globals.symbols.length]
                    options.lineWidth = 0

                  when mode is @LINES_MODE
                    options.marker =
                      symbol: 'blank'
                    options.lineWidth = 2
                    options.dashStyle = globals.dashes[si % globals.dashes.length]

              @chart.addSeries(options, false)

              # Draw the annotations
              if globals.annotationSet isnt null
                for point in series
                  if (match = globals.annotationSet.getElement globals.getDataSetId(point.datapoint[1]), \
                                                               point.datapoint[0], @canvas, fi) isnt null
                    if match.field == fi
                      match.enabled = true
                      match.draw @chart, point.x, point.y

        if @isZoomLocked()
          @updateOnZoom = false
          @setExtremes()
          $('#zoom-reset-btn').removeClass('disabled')
        else
          $('#zoom-reset-btn').addClass('disabled')

        @chart.redraw()

        @storeXBounds @chart.xAxis[0].getExtremes()
        @storeYBounds @chart.yAxis[0].getExtremes()

        # Disable/enable all of the saved regressions as necessary
        fs = globals.configs.fieldSelection
        for regr in @configs.savedRegressions
          unless regr.groups? then continue
          groupsIntersect =
            (g in data.groupSelection for g in regr.groups).reduce(
              ((p, c) -> p and c), true)

          unless regr.xAxis? and regr.yAxis? then continue
          if regr.xAxis is @configs.xAxis and groupsIntersect and
          fs.indexOf(regr.yAxis) isnt -1
            # Create the hypothesis function
            func = if regr.type is globals.REGRESSION.SYMBOLIC
              new Function("x", regr.func)
            else
              new Function("x, P", regr.func)

            # Calculate the series
            params = regr.parameters
            unless regr.type is globals.REGRESSION.SYMBOLIC
              # Convert parameters from strings to numbers
              params = for i in [0...regr.parameters.length]
                parseFloat(regr.parameters[i])

            series =
              globals.getRegressionSeries(func, params, Number(regr.r2),
                regr.type, [@configs.xBounds.min, @configs.xBounds.max],
                regr.name, regr.dashStyle, regr.id, regr.tooltip, false)[3]

            # Add the regression to the chart
            @chart.addSeries(series)

            # Enabled the class by removing the disabled class
            $('tr#' + regr.id).toggleClass('disabled', false)
          else
            $('tr#' + regr.id).toggleClass('disabled', true)

        @updateRegrTools()

        # Set Axis range to initial zoom
        $('#x-axis-min').val(@configs.xBounds.min)
        $('#x-axis-max').val(@configs.xBounds.max)
        $('#y-axis-min').val(@configs.yBounds.min)
        $('#y-axis-max').val(@configs.yBounds.max)

        if @isTimeline == true
          $('#x-axis-min').val(new Date(@configs.xBounds.min).toLocaleString())
          $('#x-axis-max').val(new Date(@configs.xBounds.max).toLocaleString())
        
      ###
      Draws radio buttons for changing symbol/line mode.
      ###
      drawToolControls: (elapsedTime = true) ->
        # Configure the tool controls
        inctx = {}
        inctx.axes = ["Both", "X", "Y"]
        inctx.logSafe = data.logSafe
        inctx.vis = @useSetAxis # To do add axis bounds feature that does time
        inctx.elapsedTime = elapsedTime and data.timeFields.length is 1
        inctx.modes = [
          { mode: @SYMBOLS_LINES_MODE, text: "Symbols and Lines" }
          { mode: @LINES_MODE,         text: "Lines Only" }
          { mode: @SYMBOLS_MODE,       text: "Symbols Only" }
        ]

        if data.hasTimeData and data.timeType != data.GEO_TIME
          inctx.period = HandlebarsTemplates[hbCtrl('period')]

        inctx.setAxis = HandlebarsTemplates[hbCtrl('set-axis-scatter')]
        if @isTimeline == true
          inctx.setAxis = HandlebarsTemplates[hbCtrl('set-axis-timeline')]

        # Draw the Tool controls
        outctx = {}
        outctx.id = 'tools-ctrls'
        outctx.title = 'Tools'
        outctx.body = HandlebarsTemplates[hbCtrl('scatter-tools')](inctx)
        tools = HandlebarsTemplates[hbCtrl('body')](outctx)

        $('#vis-ctrls').append tools
        
        # Set the correct options for period:
        $('#period-list').val(globals.configs.periodMode)

        $('#period-list').change =>
          globals.configs.periodMode = $('#period-list').val()
          if $('#period-list').val() != 'off'
            globals.configs.isPeriod = true
          else
            globals.configs.isPeriod = false
          $( "#group-by" ).trigger( "change" )
          @start()


        # Add material design
        $('#vis-ctrls').find(".mdl-checkbox").each (i,j) ->
          componentHandler.upgradeElement($(j)[0]);

        $('#vis-ctrls').find(".mdl-radio").each (i,j) ->
          componentHandler.upgradeElement($(j)[0]);

        # Check off the right boxes
        if @configs.advancedTooltips then $('#ckbx-lbl-tooltips')[0].MaterialCheckbox.check()
        if @configs.fullDetail then $('#ckbx-lbl-fulldetail')[0].MaterialCheckbox.check()
        if globals.configs.logY then $('#ckbx-lbl-log-y-axis')[0].MaterialCheckbox.check()
        $("label[name='mode'][value='#{@configs.mode}']")[0].MaterialRadio.check()

        # Set initial state of zoom reset
        if not @isZoomLocked() then $('#zoom-reset-btn').addClass("disabled")
        else $('#zoom-reset-btn').addClass("enabled")

        badNumberPopoverTimerXMin = null
        badNumberPopoverTimerXMax = null
        badNumberPopoverTimerYMin = null
        badNumberPopoverTimerYMax = null
        badNumberPopoverTimerY = null
        badNumberPopoverTimerX = null

        # Axis Manual entry for timeline
        if @isTimeline == true
          
          ###################################
          # XMin DTPicker Control
          ###################################

          # Set some variables
          calendarButtonMin = $('#x-min-cal')   # calendar button symbol
          formInputMin = $('#x-axis-min')       # textbox where the new axis min goes

          # When you click the calendar button
          # open the datetime picker and fix some font stuff
          calendarButtonMin.click ->
            dtPickerMin.open()
            $('#dt-time-textbox').css("fontSize", "13px")

          # Set some properties of the dtPicker
          dtPickerMin = calendarButtonMin.datetimepicker
            autoClose: false
            keyPress: (e) ->
              e.stopImmediatePropagation()
              e.keyCode
            onOpen: ->
              formInputMin.focus()
              formInputMin[0].value
            onChange: (val) ->
              formattedVal = val.format('M/D/YYYY h:mm:ss A')
              formInputMin.val(formattedVal)
            onKeys:
              13: -> #enter
                dtPickerMin.close()
              27: -> #escape
                dtPickerMin.close()
            anchor: $('#x-min')
            hPosition: ->
              0
            vPosition: ->
              0

          # TODO: fix dtPicker so that it closes when you click outside of it
          # jQuery(document.body).on "click", ":not(#dt-picker, #dt-picker *)", (e) ->
          #   if !(e.target.id == 'x-min-cal'
          #           || e.currentTarget.id == '#x-min'
          #           || $('#x-min').find(e.target).length != 0)
          #     dtPickerMin.close()

          ###################################
          # XMax DTPicker Control
          ###################################

          # Set some variables
          calendarButtonMax = $('#x-max-cal')   # calendar button symbol
          formInputMax = $('#x-axis-max')       # textbox where the new axis max goes

          # When you click the calendar button,
          # open the datetime picker and fix some font stuff
          calendarButtonMax.click ->
            dtPickerMax.open()
            $('#dt-time-textbox').css('cssText', 'font-size: 13px !important;')
            $('#dt-picker option').css('cssText', 'font-size: 13px !important;')

          # Set some properties of the dtPicker
          dtPickerMax = calendarButtonMax.datetimepicker
            autoClose: false
            keyPress: (e) ->
              e.stopImmediatePropagation()
              e.keyCode
            onOpen: ->
              formInputMax.focus()
              formInputMax[0].value
            onChange: (val) ->
              formattedVal = val.format('M/D/YYYY h:mm:ss A')
              formInputMax.val(formattedVal)
            onKeys:
              13: -> #enter
                dtPickerMax.close()
              27: -> #escape
                dtPickerMax.close()
            anchor: $('#x-max')
            hPosition: ->
              0
            vPosition: ->
              0

          # TODO: fix dtPicker so that it closes when you click outside of it
          # jQuery(document.body).on "click", ":not(#dt-picker, #dt-picker *)", (e) ->
          #   if !(e.target.id == 'x-max-cal'
          #         || e.currentTarget.id == '#x-max'
          #         || $('#x-max').find(e.target).length != 0)
          #     dtPickerMax.close()

          ###################################
          # get values as numbers
          ###################################
          $('#set-axis-button').click =>
 
            xAxisMin = Date.parse($('#x-axis-min').val())
            xAxisMax = Date.parse($('#x-axis-max').val())
             # error checking
            thereIsAFailure = false
            if xAxisMin >= xAxisMax
              thereIsAFailure = true
              $('#x-axis-min').popover
                content: 'Left must be less than right'
                placement: 'bottom'
                trigger: 'manual'
              $('#x-axis-min').popover('show')
              if badNumberPopoverTimerX? then clearTimeout(badNumberPopoverTimerX)
              badNumberPopoverTimerX = setTimeout ->
                $('#x-axis-min').popover('destroy')
              , 3000

            if thereIsAFailure then return

            $('#x-axis-min').popover('destroy')
            $('#x-axis-max').popover('destroy')

            @configs.xBounds.min = xAxisMin
            @configs.xBounds.max = xAxisMax
 
            @setExtremes()
  
	      # Axis Manual entry for scatter
        if @isTimeline == null

          $('#set-axis-button').click =>

            thereIsAFailure = false

            xAxisMin = $('#x-axis-min').val()
            xAxisMax = $('#x-axis-max').val()
            yAxisMin = $('#y-axis-min').val()
            yAxisMax = $('#y-axis-max').val()

            if isNaN(xAxisMin) or xAxisMin == ""
              thereIsAFailure = true
              $('#x-axis-min').popover
                content: 'Please enter a valid number'
                placement: 'bottom'
                trigger: 'manual'
              $('#x-axis-min').popover('show')
              if badNumberPopoverTimerXMin? then clearTimeout(badNumberPopoverTimerXMin)
              badNumberPopoverTimerXMin = setTimeout ->
                $('#x-axis-min').popover('destroy')
              , 3000
  
            if isNaN(xAxisMax) or xAxisMax == ""
              thereIsAFailure = true
              $('#x-axis-max').popover
                content: 'Please enter a valid number'
                placement: 'bottom'
                trigger: 'manual'
              $('#x-axis-max').popover('show')
              if badNumberPopoverTimerXMax? then clearTimeout(badNumberPopoverTimerXMax)
              badNumberPopoverTimerXMax = setTimeout ->
                $('#x-axis-max').popover('destroy')
              , 3000
  
            if isNaN(yAxisMin) or yAxisMin == ""
              thereIsAFailure = true
              $('#y-axis-min').popover
                content: 'Please enter a valid number'
                placement: 'bottom'
                trigger: 'manual'
              $('#y-axis-min').popover('show')
              if badNumberPopoverTimerYMin? then clearTimeout(badNumberPopoverTimerYMin)
              badNumberPopoverTimerYMin = setTimeout ->
                $('#y-axis-min').popover('destroy')
              , 3000
  
            if isNaN(yAxisMax) or yAxisMax == ""
              thereIsAFailure = true
              $('#y-axis-max').popover
                content: 'Please enter a valid number'
                placement: 'bottom'
                trigger: 'manual'
              $('#y-axis-max').popover('show')
              if badNumberPopoverTimerYMax? then clearTimeout(badNumberPopoverTimerYMax)
              badNumberPopoverTimerYMax = setTimeout ->
                $('#y-axis-max').popover('destroy')
              , 3000
  
            if thereIsAFailure then return
  
            xAxisMin = Number(xAxisMin)
            xAxisMax = Number(xAxisMax)
            yAxisMin = Number(yAxisMin)
            yAxisMax = Number(yAxisMax)
  
            if xAxisMin >= xAxisMax
              thereIsAFailure = true
              $('#x-axis-min').popover
                content: 'Left must be less than right'
                placement: 'bottom'
                trigger: 'manual'
              $('#x-axis-min').popover('show')
              if badNumberPopoverTimerX? then clearTimeout(badNumberPopoverTimerX)
              badNumberPopoverTimerX = setTimeout ->
                $('#x-axis-min').popover('destroy')
              , 3000
  
            if yAxisMin >= yAxisMax
              thereIsAFailure = true
              $('#y-axis-min').popover
                content: 'Left must be less than right'
                placement: 'bottom'
                trigger: 'manual'
              $('#y-axis-min').popover('show')
              if badNumberPopoverTimerY? then clearTimeout(badNumberPopoverTimerY)
              badNumberPopoverTimerY = setTimeout ->
                $('#y-axis-min').popover('destroy')
              , 3000
  
            if thereIsAFailure then return
  
            $('#x-axis-min').popover('destroy')
            $('#x-axis-max').popover('destroy')
            $('#y-axis-min').popover('destroy')
            $('#y-axis-max').popover('destroy')
  
            @configs.xBounds.min = xAxisMin
            @configs.xBounds.max = xAxisMax
  
            @configs.yBounds.min = yAxisMin
            @configs.yBounds.max = yAxisMax
  
            @setExtremes()

        $('#zoom-reset-btn').click (e) =>
          @resetExtremes($('#zoom-axis-list').val())

        $('#zoom-out-btn').click (e) =>
          @zoomOutExtremes($('#zoom-axis-list').val())

        $('input[name="mode"]').click (e) =>
          @configs.mode = Number e.target.value
          @start()

        $('#ckbx-tooltips').click (e) =>
          @configs.advancedTooltips = (@configs.advancedTooltips + 1) % 2
          @start()
          true

        $('#ckbx-fulldetail').click (e) =>
          @configs.fullDetail = (@configs.fullDetail + 1) % 2
          @delayedUpdate()
          true

        $('#ckbx-log-y-axis').click (e) =>
          globals.configs.logY = !globals.configs.logY
          @start()

        $('#elapsed-time-btn').click (e) ->
          globals.generateElapsedTime()

        # Initialize and track the status of this control panel
        globals.configs.toolsOpen ?= false
        initCtrlPanel('tools-ctrls', 'toolsOpen')

        # Add material design
        $('#vis-ctrls').find(".mdl-checkbox").each (i,j) ->
          componentHandler.upgradeElement($(j)[0]);

        $('#vis-ctrls').find(".mdl-radio").each (i,j) ->
          componentHandler.upgradeElement($(j)[0]);

      ###
      A wrapper for making x-axis controls
      ###
      drawXAxisControls: (iniRadio = @configs.xAxis,
        allFields = data.normalFields) ->
        handler = (selection, selFields) =>
          @configs.xAxis = selection
          @resetExtremes()
          @update()

        @drawAxisControls('x-axis', 'X Axis', null, allFields, true,
          iniRadio, handler)

        # Initialize and track the status of this control panel
        globals.configs.xAxisOpen ?= false
        initCtrlPanel('x-axis-ctrls', 'xAxisOpen')

      ###
      Checks if the user has requested a specific zoom
      ###
      isZoomLocked: ->
        not (undefined in [@configs.xBounds.userMin, @configs.xBounds.userMax])

      resetExtremes: (whichAxis = 'Both') =>
        if @chart isnt undefined
          if whichAxis in ['Both', 'X']
            @configs.xBounds.userMin = undefined
            @configs.xBounds.userMax = undefined
            @chart.xAxis[0].setExtremes()
          if whichAxis in ['Both', 'Y']
            @configs.yBounds.userMin = undefined
            @configs.yBounds.userMax = undefined
            @chart.yAxis[0].setExtremes()

      setExtremes: ->
        if @chart?
          if(@configs.xBounds.min? and @configs.yBounds.min?)
            @chart.xAxis[0].setExtremes(@configs.xBounds.min,
              @configs.xBounds.max, true)
            @chart.yAxis[0].setExtremes(@configs.yBounds.min,
              @configs.yBounds.max, true)
          else
            @resetExtremes()

      zoomOutExtremes: (whichAxis) ->
        xRange = @configs.xBounds.max - @configs.xBounds.min
        yRange = @configs.yBounds.max - @configs.yBounds.min

        if whichAxis in ['Both', 'X']
          @configs.xBounds.max += xRange * 0.1
          @configs.xBounds.min -= xRange * 0.1

        if whichAxis in ['Both', 'Y']
          if globals.configs.logY
            @configs.yBounds.max *= 10.0
            @configs.yBounds.min /= 10.0
          else
            @configs.yBounds.max += yRange * 0.1
            @configs.yBounds.min -= yRange * 0.1

        @setExtremes()

      ###
      Saves the current zoom level
      ###
      end: ->
        super()

      ###
      Saves the zoom level before cleanup
      ###
      serializationCleanup: ->
        if chart?
          @storeXBounds @chart.xAxis[0].getExtremes()
          @storeYBounds @chart.yAxis[0].getExtremes()

        super()

      ###
      Updates regression control labels
      ###
      updateRegrTools:() ->
        $('#regr-x-axis').text("#{data.fields[@configs.xAxis].fieldName}")
        if $('#regr-y-axis')? then $('#regr-y-axis').empty()
        for f in globals.configs.fieldSelection
          # TODO template this out
          $('#regr-y-axis').append($("<option/>", {
            value: f,
            text: data.fields[f].fieldName
          }))

        # Display the table header if necessary
        len = $('#regr-table-body > tr').length
        $('tr#regr-table-header').toggle(len > 1)

      ###
      Adds the regression tools to the control bar.
      ###
      drawRegressionControls: () ->
        regressions = ['Linear', 'Quadratic', 'Cubic', 'Exponential',
            'Logarithmic', 'Automatic']

        inctx =
          xAxis: data.fields[@configs.xAxis].fieldName
          yFields:
            for f in globals.configs.fieldSelection
              name: data.fields[f].fieldName
              id: f
          regressions: regressions

        outctx = {}
        outctx.id = 'regression-ctrls'
        outctx.title = 'Analysis Tools'
        outctx.body = HandlebarsTemplates[hbCtrl('regr')](inctx)
        tools = HandlebarsTemplates[hbCtrl('body')](outctx)
        $('#vis-ctrls').append tools

        # Adds material design
        $('#vis-ctrls').find(".mdl-checkbox").each (i,j) ->
          componentHandler.upgradeElement($(j)[0]);

        $('#vis-ctrls').find(".mdl-radio").each (i,j) ->
          componentHandler.upgradeElement($(j)[0]);

        # Initialize and track the status of this control panel
        globals.configs.regressionOpen ?= false
        initCtrlPanel('regression-ctrls', 'regressionOpen')

        # Restore saved regressions if they exist
        fs = globals.configs.fieldSelection
        for regr in @configs.savedRegressions
          # this if statement is a fix that prevents certain projects from halting during rendering.
          if typeof regr.groups != 'undefined'
            groupsIntersect =
              (g in data.groupSelection for g in regr.groups).reduce(
                ((p, c) -> p and c), true)

            enabled = regr.xAxis is @configs.xAxis and groupsIntersect and
              fs.indexOf(regr.yAxis) isnt -1

            # Calculate the hypothesis function
            func =
              if regr.type is globals.REGRESSION.SYMBOLIC
                new Function("x", regr.func)
              else
                new Function("x, P", regr.func)

            # Calculate the series
            params = regr.parameters
            unless regr.type is globals.REGRESSION.SYMBOLIC
              # Convert parameters from strings to numbers
              params = for i in [0...regr.parameters.length]
                parseFloat(regr.parameters[i])

            series =
              globals.getRegressionSeries(func, params, Number(regr.r2),
                regr.type, [@configs.xBounds.min, @configs.xBounds.max],
                regr.name, regr.dashStyle, regr.id, regr.tooltip, false)[3]

            # Add the regression to the chart
            if enabled then @chart.addSeries(series)
            @addRegressionToTable(regr, enabled)

        # Create a new regression
        $('#draw-regr-btn').click =>
          yAxisIndex = Number($('#regr-y-axis').val())
          regrType = Number($('#regr-type').val())

          # Make the title for the tooltip
          xAxisName = data.fields[@configs.xAxis].fieldName
          yAxisName = $('#regr-y-axis option:selected').text()

          # TODO template this out
          name = "<strong>#{yAxisName}</strong> as a "
          desc = ''
          if regrType isnt globals.REGRESSION.SYMBOLIC
            desc = "#{$('#regr-type option:selected').text().toLowerCase()} "
          name += desc + "function of <strong>#{xAxisName}</strong>"

          # List of (x,y) points to be used in calculating regression
          dp = globals.getData(true, globals.configs.activeFilters)
          xyData = data.multiGroupXYSelector(@configs.xAxis, yAxisIndex,
            data.groupSelection, dp)
          xMax = window.globals.curVis.configs.xBounds.max
          xMin = window.globals.curVis.configs.xBounds.min
          points = ({x: point.x, y: point.y} for point in xyData)
          fn = (pv, cv, index, array) -> (pv and cv)

          # Create a unique identifier for the regression
          regrId = "regr-x-#{@configs.xAxis}-y-#{yAxisIndex}-t-#{regrType}-g-" +
            data.groupSelection.toString()
          regrId = regrId.replace(',', '-') while regrId.indexOf(',') isnt -1
          return unless (r.id isnt regrId for r in @configs.savedRegressions).reduce(fn, true)

          # Get dash index
          dashIndex = data.normalFields.indexOf(yAxisIndex)
          dashStyle = globals.dashes[dashIndex % globals.dashes.length]

          [func, Ps, r2, newRegr, tooltip] = [null, null, null, null, null]
          if regrType is globals.REGRESSION.SYMBOLIC
            [func, Ps, r2, newRegr, tooltip] = globals.getRegression(
              points,
              regrType,
              [xMin, xMax],
              name,
              dashStyle,
              regrId
            )
          else
            try
              [func, Ps, r2, newRegr, tooltip] = globals.getRegression(
                points,
                regrType,
                [xMin, xMax],
                name,
                dashStyle,
                regrId
              )
            catch error
              if regrType is 3
                alert("Unable to calculate an #{regressions[regrType]} " +
                "regression for this data.")
              else
                alert("Unable to calculate a #{regressions[regrType]} " +
                "regression for this data.")
              return

          # Add the series
          @chart.addSeries(newRegr)

          # Set func var to a string so it can be restored later
          if typeof(func) is 'function'
            func = switch regrType
              when globals.REGRESSION.LINEAR
                'return P[0] + (P[1] * x)'
              when globals.REGRESSION.QUADRATIC
                'return P[0] + (P[1] * x) + (P[2] * x * x)'
              when globals.REGRESSION.CUBIC
                'return P[0] + (x * P[1]) + (x * x * P[2]) + (x * x * x * P[3])'
              when globals.REGRESSION.EXPONENTIAL
                'return P[0] + Math.exp(P[1] * x + P[2])'
              when globals.REGRESSION.LOGARITHMIC
                'return P[0] + Math.log(P[1] * x + P[2])'
          else
            func = BinaryTree.codify(func.tree)

          # Prepare to save regression fields
          savedRegression =
            type: regrType
            xAxis: @configs.xAxis
            yAxis: yAxisIndex
            groups: data.groupSelection.slice(0)
            parameters: Ps
            func: func
            id: regrId
            r2: r2
            name: name
            dashStyle: dashStyle
            tooltip: tooltip

          # Save a regression
          @configs.savedRegressions.push(savedRegression)

          # Actually add the regression to the table
          @addRegressionToTable(savedRegression, true)

          # Draw the regression to the vis
          @start()

      # Adds a regression row to our table, with styling for enabled or disabled
      addRegressionToTable: (savedReg, enabled) ->
        # Here have a list of regressions
        regressions = ['Linear', 'Quad', 'Cubic', 'Exp', 'Log', 'Auto']

        # Add the entry used the passed regression
        ctx =
          id: savedReg.id
          logId: 'regr-' + @configs.savedRegressions.length
          name: data.fields[savedReg.yAxis].fieldName +
            "(#{data.fields[savedReg.xAxis].fieldName})"
          type: regressions[savedReg.type]

        regressionRow = HandlebarsTemplates[hbCtrl('regr-row')](ctx)
        @updateRegrTools()

        # Added info relating to this regression
        $('#regr-table-body').append(regressionRow)

        # Add the disabled style if necessary
        unless enabled then $('tr#' + savedReg.id).addClass('disabled')

        # Make each row a link to its view
        $('tr#' + savedReg.id).click =>
          # Reset the state of when you saved
          @configs.xAxis = savedReg.xAxis
          globals.configs.fieldSelection = [savedReg.yAxis]
          data.groupSelection = savedReg.groups
          @start()

        # Add a make the delete button remove the regression object
        $('tr#' + savedReg.id + '> .remove').click =>
          # Remove regression view from the screen.
          $('tr#' + savedReg.id).remove()

          # Remove regression from the savedRegressions array.
          for r, i in @configs.savedRegressions
            if (r.id is savedReg.id)
              @configs.savedRegressions.splice(i, 1)
              break

          # Remove regression from the chart
          for series, i in @chart.series
            if (series.name.id is savedReg.id)
              @chart.series[i].remove()
              break

          @updateRegrTools()

        # Make the hovering highlight the correct regression
        $('tr#' + savedReg.id).mouseover =>
          for series, i in @chart.series
            if (series.name.id is savedReg.id)
              @chart.series[i].setState('hover')
              midpoint = globals.REGRESSION.NUM_POINTS / 2
              @chart.tooltip.refresh(@chart.series[i].points[midpoint])
              break

        # When the mouse leaves, don't highlight anymore
        $('tr#' + savedReg.id).mouseout =>
          for series, i in @chart.series
            if (series.name.id == savedReg.id)
              @chart.series[i].setState()
              @chart.tooltip.hide()
              break

      saveFilters: (vis = 'scatter') ->
        super(vis)

        # Verify parameters
        unless @configs.xBounds.min? and @configs.xBounds.max? and
        @configs.yBounds.min? and @configs.yBounds.max?
          return

        # Start with x boundaries
        filters = [
          vis: vis
          op:  'gt'
          field: @configs.xAxis
          value: @configs.xBounds.min
        ,
          vis: vis
          op:  'lt'
          field: @configs.xAxis
          value: @configs.xBounds.max
        ]

        # Check all y axes
        for yAxis in globals.configs.fieldSelection
          if yAxis is @configs.xAxis
            filters[0].value = Math.max(filters[0].value, @configs.yBounds.min)
            filters[1].value = Math.min(filters[1].value, @configs.yBounds.max)
          else
            filters.push
              vis: vis
              op:  'gt'
              field: yAxis
              value: @configs.yBounds.min
            ,
              vis: vis
              op:  'lt'
              field: yAxis
              value: @configs.yBounds.max

        for filter in filters
          globals.configs.activeFilters.push(filter)
    
    if "Scatter" in data.relVis
      globals.scatter = new Scatter "scatter-canvas"
    else
      globals.scatter = new DisabledVis "scatter-canvas"
