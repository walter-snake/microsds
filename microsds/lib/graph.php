<?php
/* pChart library inclusions */
include("../lib-ext/pchart/pData.class.php");
include("../lib-ext/pchart/pDraw.class.php");
include("../lib-ext/pchart/pImage.class.php");
include("../lib-ext/pchart/pScatter.class.php");

class graph {
  private $data;
  private $statid;

  function __construct($data, $statid)
  {
    $this->data = $data;
    $this->statid = $statid;
  }

  public function getGraph($mproperty, $format, $legend)
  {
    /* Create and populate the pData object with the temperature series*/
    $MyData = new pData();  
    while ($row = pg_fetch_row($this->data))
    {
      $MyData->addPoints($this->convert_datetime($row[1]), "Timestamp");
      $MyData->addPoints($row[4], "Serie1");
      $MyStation = $row[6];
    }
    $MyData->setAxisXY(0,AXIS_X);
    $MyData->setAxisXY(1,AXIS_Y);
    $MyData->setSerieOnAxis("Timestamp", 0);
    $MyData->setSerieOnAxis("Serie1", 1);
    $MyData->setAxisName(0,"Timestamp");
    $MyData->setAxisName(1,$legend);
    $MyData->setScatterSerie("Timestamp", "Serie1", 1);
    $MyData->setAxisDisplay(0, AXIS_FORMAT_TIME,"Y-m-d H:i");
    $MyData->setScatterSerieDescription(0, "Timestamp");
    $MyData->setScatterSerieDescription(1, $legend);
    $MyData->setScatterSerieColor(1,array("R"=>0,"G"=>128,"B"=>64));
    $MyData->setAxisPosition(0,AXIS_POSITION_BOTTOM);
    $MyData->setAxisPosition(1,AXIS_POSITION_LEFT);

    if ($format == "micro")
      $this->microGraph($MyData, $legend);
    else
      $this->graphIt($MyData, "Station name: ".$MyStation, $legend);
  }

  // Tiny graph
  function microGraph($graphData, $legend)
  {
    $graphData->setAxisDisplay(0, AXIS_FORMAT_TIME,"H:i");

    /* Create the pChart object */
    $myPicture = new pImage(280,100,$graphData);

    /* Turn off Antialiasing */
    $myPicture->Antialias = FALSE;

    /* Overlay with a gradient */
    $Settings = array("StartR"=>219, "StartG"=>231, "StartB"=>139, "EndR"=>1, "EndG"=>138, "EndB"=>68, "Alpha"=>50);
    $myPicture->drawGradientArea(0,0,280,100,DIRECTION_VERTICAL,$Settings);
    $myPicture->setFontProperties(array("FontName"=>"../lib-ext/fonts/verdana.ttf","FontSize"=>5,"R"=>0,"G"=>0,"B"=>0));

    /* Define the chart area */
    $myPicture->setGraphArea(40,5,250,70);

    /* Draw the scale */
    $scaleSettings = array("XMargin"=>0,"YMargin"=>3,"Floating"=>False,"GridR"=>128,"GridG"=>128,"GridB"=>128,"DrawSubTicks"=>FALSE,"CycleBackground"=>FALSE,"LabelSkip"=>50);

    /* Turn on Antialiasing */
    $myPicture->Antialias = TRUE;

    // Check if there's any data at all
    if ($graphData->getSerieCount("Timestamp") == 0)
    {
      // write a message about missing data
      $myPicture->drawText(5,30,"No current data\n  (< 24 hours)",array("FontSize"=>10,"Align"=>TEXT_ALIGN_BOTTOMLEFT));
    }
    else
    {
      $myScatter = new pScatter($myPicture, $graphData);
      $myScatter->drawScatterScale($scaleSettings);
      $myScatter->drawScatterPlotChart(array("PlotSize"=>1));
      $myScatter->drawScatterLineChart();
    }

    /* Render the picture (choose the best way) */
    //$myPicture->stroke();
    $myPicture->autoOutput('msd.micrograph.png');
  }

  function graphIt($graphData, $graphTitle, $legend)
  {
    /* Create the pChart object */
    $myPicture = new pImage(700,480,$graphData);

    /* Turn off Antialiasing */
    $myPicture->Antialias = FALSE;

    /* Draw the background */
    $Settings = array("R"=>170, "G"=>183, "B"=>87, "Dash"=>1, "DashR"=>190, "DashG"=>203, "DashB"=>107);
    $myPicture->drawFilledRectangle(60,50,650,320,$Settings);

    /* Overlay with a gradient */
    $Settings = array("StartR"=>219, "StartG"=>231, "StartB"=>139, "EndR"=>1, "EndG"=>138, "EndB"=>68, "Alpha"=>50);
    $myPicture->drawGradientArea(0,0,700,480,DIRECTION_VERTICAL,$Settings);
    $myPicture->drawGradientArea(0,0,700,40,DIRECTION_VERTICAL,array("StartR"=>0,"StartG"=>0,"StartB"=>0,"EndR"=>50,"EndG"=>50,"EndB"=>50,"Alpha"=>80));

    /* Add a border to the picture */
    $myPicture->drawRectangle(0,0,699,479,array("R"=>0,"G"=>0,"B"=>0));

    /* Write the chart title */ 
    $now = new DateTime();
    $myPicture->setFontProperties(array("FontName"=>"../lib-ext/fonts/verdana.ttf","FontSize"=>8,"R"=>255,"G"=>255,"B"=>255));
    $myPicture->drawText(10,8,$graphTitle."\nCurrent date: ".$now->format("Y-m-d H:i:s")."; Station ID: ".$this->statid."]",array("FontSize"=>9,"Align"=>TEXT_ALIGN_TOPLEFT));

    /* Set the default font */
    $myPicture->setFontProperties(array("FontName"=>"../lib-ext/fonts/verdana.ttf","FontSize"=>8,"R"=>0,"G"=>0,"B"=>0));

    /* Define the chart area */
    $myPicture->setGraphArea(60,40,650,320);

    /* Draw the scale */
    $scaleSettings = array("XMargin"=>10,"YMargin"=>10,"Floating"=>TRUE,"GridR"=>200,"GridG"=>200,"GridB"=>200,"DrawSubTicks"=>FALSE,"CycleBackground"=>FALSE,"LabelSkip"=>25);

    /* Turn on Antialiasing */
    $myPicture->Antialias = TRUE;

    /* Enable shadow computing */
    $myPicture->setShadow(TRUE,array("X"=>1,"Y"=>1,"R"=>0,"G"=>0,"B"=>0,"Alpha"=>10));

    // Check if there's any data at all
    if ($graphData->getSerieCount("Timestamp") == 0)
    {
      // write a message about missing data
      $myPicture->drawText(100,100,"No current data available (< 24 hours).",array("FontSize"=>10,"Align"=>TEXT_ALIGN_BOTTOMLEFT));
    }
    else
    {
      $myScatter = new pScatter($myPicture, $graphData);
      $myScatter->drawScatterScale($scaleSettings);
      $myScatter->drawScatterPlotChart(array("PlotSize"=>1));
      $myScatter->drawScatterLineChart();

      /* Write the chart legend */
      $myScatter->drawScatterLegend(540,9,array("Style"=>LEGEND_NOBORDER,"Mode"=>LEGEND_HORIZONTAL,"FontR"=>255,"FontG"=>255,"FontB"=>255));
    }

    /* Render the picture (choose the best way) */
    $myPicture->autoOutput('msd.graph.png');
    //$myPicture->stroke();
  }

  // Concert a date string to a datetime object (input: yyyy-mm-dd hh:mm:ss)
  function convert_datetime($str) 
  {
    list($date, $time) = explode(' ', $str);
    list($year, $month, $day) = explode('-', $date);
    list($hour, $minute, $second) = explode(':', $time);
    $timestamp = mktime($hour, $minute, $second, $month, $day, $year);
    return $timestamp;
  }
}
?>
