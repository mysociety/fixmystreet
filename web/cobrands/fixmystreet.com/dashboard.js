$(function(){

    Chart.defaults.global.defaultFontSize = 16;

    var setUpLabelsForChart = function(chart){
        var $parent = $(chart.chart.canvas).parent();
        var xGutterInPixels = 30;

        var lasty = 0;
        $.each(chart.config.data.datasets, function(datasetIndex, dataset){
            var $label = $('.label[data-datasetIndex="' + datasetIndex + '"]', $parent);
            var latestPoint = chart.getDatasetMeta(datasetIndex).data[ dataset.data.length - 1 ];
            var y = latestPoint._model.y;
            if (y < lasty) {
                y = lasty;
            }
            $label.css({
                top: y,
                left: latestPoint._model.x + xGutterInPixels
            });
            lasty = y + $label.height() + 8;
        });
    };

    // Returns an array `numberOfPoints` long, where the final item
    // is `radius`, and all the other items are 0.
    var pointRadiusFinalDot = function(numberOfPoints, radius){
        var pointRadius = [];
        for (var i=1; i < numberOfPoints; i++) {
            pointRadius.push(0);
        }
        pointRadius.push(radius);
        return pointRadius;
    };

    var makeSparkline = function makeSparkline($el, valuesStr, color, title){
        var values = [];
        var labels = [];
        $.each(valuesStr.split(' '), function(key, value){
            values.push(Number(value));
            labels.push('');
        });
        var spread = Math.max.apply(null, values) - Math.min.apply(null, values);

        return new Chart($el, {
            type: 'line',
            data: {
                labels: labels,
                datasets: [{
                    data: values,
                    pointRadius: pointRadiusFinalDot(values.length, 4),
                    pointBackgroundColor: color,
                    borderColor: color,
                    lineTension: 0
                }]
            },
            options: {
                layout: {
                    padding: {
                        top: 0,
                        right: 5,
                        bottom: 0,
                        left: 2
                    }
                },
                scales: {
                    xAxes: [{
                        type: "category",
                        display: false
                    }],
                    yAxes: [{
                        type: "linear",
                        display: false,
                        ticks: {
                            min: Math.min.apply(null, values) - (spread * 0.3),
                            max: Math.max.apply(null, values) + (spread * 0.3)
                        }
                    }]
                }
            }
        });
    };

    $('.labelled-sparkline canvas').each(function(){
        makeSparkline(
            $(this),
            $(this).data('values'),
            $(this).data('color')
        );
    });

    var $allReports = $('#chart-all-reports'),
        labels = $allReports.data('labels'),
        data0 = $allReports.data('values-reports'),
        data1 = $allReports.data('values-fixed');
    window.chartAllReports = new Chart($allReports, {
        type: 'line',
        data: {
            labels: labels,
            datasets: [{
                data: data0,
                pointRadius: pointRadiusFinalDot(data0.length, 4),
                pointBackgroundColor: '#F4A140',
                borderColor: '#F4A140'
            }, {
                data: data1,
                pointRadius: pointRadiusFinalDot(data1.length, 4),
                pointBackgroundColor: '#62B356',
                borderColor: '#62B356'
            }]
        },
        options: {
            animation: {
                onComplete: function(){
                    setUpLabelsForChart(this);
                }
            },
            layout: {
                padding: {
                    top: 4
                }
            },
            scales: {
                xAxes: [{
                    type: 'category',
                    gridLines: {
                        display: false
                    }
                }],
                yAxes: [{
                    type: "linear",
                    ticks: {
                        display: false
                    }
                }]
            },
            onResize: function(chart, size){
                setUpLabelsForChart(chart);
            }
        }
    });
});
