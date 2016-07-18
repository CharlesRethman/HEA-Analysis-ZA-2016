# Converting Remote Sensing Images to Polygons (showing affected areas) using QGIS and PostGIS

This process "back-converts" full colour (e.g. R-Y-G) remote sensing images (such as NDVI, VCI, RFE, etc.) to to polygons based on the colour groupings. Of course, it would be much easier to just obtain single colour images where the colour value corresponds to the legend value but get those from the custodian agency?!!! Maybe... one day... maybe they'll even have an API.

### Steps:

1. After georeferencing, load the RS image into QGIS and note the colour gradations (for example: dark red, red, dark orange, light Orange, yellow, neon green, light green, green, dark green).
2. Open the `Style` tab on the `Properties` dialog. Choose `Multiband color` and now you will tweak the red or green band values so that the reds and greens do not have the same numbers when converted to greyscale (e.g. dark red must have a different green band number from the red band of dark green). Use the Digital Color Meter app or a colour picker to check these values. Select `Render in grayscale` to `By luminosity` and click `Apply`. Check the grey scale value on the Digital Color Meter and compare the red with its opposite green value.
3. Save the rendered greyscale RS image raster to a new file (I usually end it with `_grscale`). Make sure the `Rendered` box is checked to have the greyscale come through.
4. Load the greyscale RS image into QGIS. Use `Raster`>`Conversion`>`Polygonize (Raster to Vector)...` to generate the new polygon shape file. Keep the CRS the same as your database.
5. Import the polygon into your PostGIS database, ensuring the appropriate CRS.
6. Run `sql/buffer_rs.sql` to create a buffer layer on the polygon output. This will 'generalise' the hazard area a little, fill in holes and remove extraneous small pixels.
7. This last layer can be compared with an agricultural region (to determine a problem spec) or directly with livelihood zones (to determine affected extents).
