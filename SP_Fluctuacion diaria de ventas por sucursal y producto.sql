CREATE PROCEDURE FluctuacionVentasPivoteado
/*

El SP recibe una ventana temporal (@startdate, @enddate) y devuelve la fluctuación de ventas diaria
por SUCURSAL y por PRODUCTO pivoteada.

*/
	@startdate	DATE,
	@enddate	DATE 

AS

BEGIN

	DECLARE @startdateframe DATE = @startdate
	DECLARE @enddateframe	DATE = @enddate
	
	DECLARE @DatesTable TABLE (	FechaAux DATE )
	
	WHILE (@startdate <= @enddate) 
		BEGIN
	
		  INSERT INTO @DatesTable (FechaAux) VALUES( @startdate )
		  SELECT @startdate = DATEADD(DAY, 1, @startdate )
	
		END



	DECLARE @query NVARCHAR(MAX)
	DECLARE @cols NVARCHAR(MAX)
	
	SELECT @cols = STUFF((SELECT ',' + QUOTENAME(CONVERT(VARCHAR(10), FechaAux, 120)) 
	                      FROM @DatesTable
	                      WHERE FechaAux >=  @startdateframe			       
	                        AND FechaAux <=  @enddateframe			  
	                      GROUP BY FechaAux
	                      ORDER BY FechaAux
	                      FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)')
						  ,1,1,'')
	
	SET @query = N' SELECT Sucursal, Categoria, ProductoId, Descripcion, '+ @cols+ ' 
	                FROM (
						  SELECT Fecha, 
						         Sucursal,
						     	 Categoria, 
						     	 ProductoId, 
						     	 Descripcion, 
						     	 DifDiaAnt
						  FROM (
						     	SELECT *, 
						     	       VolumenVentas - LAG(tb.VolumenVentas, 1, 0) OVER(PARTITION BY tb.ProductoId 
									                                                    ORDER BY tb.Fecha) AS DifDiaAnt
						     	FROM ( 
						       		  SELECT CONVERT(DATE, vc.TranFechaHora) AS Fecha, 
						     		         cp.Nombre AS Categoria, 
						     		         p.ProductoId, 
						     		         p.Descripcion,
						     		         ee.Descripcion AS Sucursal,
						     		         SUM(vcd.Cantidad) AS VolumenVentas 
						     		  FROM Productos AS p 
						     		  INNER JOIN CategoriaProductos AS cp
						     		  ON p.CategoriaProductoId = cp.CategoriaProductoId
						     		  INNER JOIN ventas.VentaCajaDetalle AS vcd
						     		  ON p.ProductoId = vcd.ProductoId
						     		  INNER JOIN ventas.VentaCaja AS vc
						     		  ON vc.VentaId = vcd.VentaId
						     		  INNER JOIN Empresa.EstructuraEmpresa AS ee
						     		  ON vc.SucursalId = ee.EstructuraId
						     		  GROUP BY ee.Descripcion, p.ProductoId, cp.Nombre, p.Descripcion, CONVERT(DATE, vc.TranFechaHora)
						     		 ) AS tb
						        ) AS tb2
						  ) AS tb3
	                PIVOT
	                (AVG(DifDiaAnt) FOR Fecha IN ('+ @cols+ ')) AS pvt';

	EXEC(@query)

END

GO

/*
EXEC FluctuacionVentasPivoteado 
	'2022-04-20',
	'2022-05-20'
*/