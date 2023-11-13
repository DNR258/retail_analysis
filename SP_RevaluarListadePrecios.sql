/* 
FUNCIONES REQUERIDAS PARA EL STORE PROCEDURE

1) Nombre: fn_ListaIntoTabla
*/

CREATE FUNCTION fn_ListaIntoTabla (@Lista VARCHAR(MAX))
/* 
La función recibe un STRING con una lista de valores separados por coma (,) y devueve una tabla con los mismos valores
*/
RETURNS @ProductosTable TABLE (ProdId BIGINT)
AS
BEGIN
    DECLARE @ParamItem VARCHAR(50)                                         
	WHILE CHARINDEX( ',', @Lista ) > 0 
	
		BEGIN
			SET @ParamItem = LTRIM(RTRIM( SUBSTRING( @Lista , 1, CHARINDEX( ',', @Lista ) -1)))
			
			SET @Lista = SUBSTRING( @Lista , CHARINDEX( ',', @Lista ) + 1, len(@Lista)) 
			
			INSERT @ProductosTable (ProdId) VALUES (@ParamItem)
		
		END
	IF LEN(rtrim(@Lista) ) != '' 
		BEGIN    
		
			SET @ParamItem = LTRIM(RTRIM(@Lista))
		 
			INSERT @ProductosTable ( ProdId ) VALUES (@ParamItem )
		END
	RETURN
END
GO


/* 
2) Nombre: fn_IncrementoPrecio 
*/ 

CREATE FUNCTION dbo.fn_IncrementoPrecio(@Precio NUMERIC(18,4),@TipoIncremento INT, @Incremento NUMERIC(18,4))
/*
La función recibe 3 argumentos (Precio, Tipo de incremento, e Incremento) devuelve el precio actualizado de un producto. 

@Precio:                  valor NUMERIC sobre el que se calcularán los aumentos

@TipoIncremento:          valor ENTERO, 1 para porcentaje y 2 para aumento de un valor fijo

@Incremento:              valor NUMERIC donde se define el aumento dependiendo sea porcentaje o valor de incremento fijo.
*/
RETURNS NUMERIC(18,4)
AS 
BEGIN
    IF @TipoIncremento = 1
	BEGIN
	SET @Precio = @precio + (@precio * @Incremento/100)
	END
	IF @TipoIncremento = 2
	BEGIN
	SET @Precio = @precio + @Incremento
	END
RETURN @Precio
END
GO 

/* 
SP Nombre:   RevaluarListadePrecios
*/

 CREATE PROCEDURE RevaluarListadePrecios
	@TipoIncremento           INT                 , 
	@CategoriaListaPrecioId   INT                 ,   
	@CategoriaProductos       VARCHAR(MAX) = NULL ,  
	@Productos                VARCHAR(MAX) = NULL ,
	@Incremento               NUMERIC(18,4)       ,
	@FechaHoraDesde           DATE                , 
	@FechaHoraHasta           DATE         = NULL

/*
Determinado los argumentos introducidos son correctos y válidos, toma la lista inmediata anterior, 
             y replica la misma lista con los incrementos de precio correspondientes.

@TipoIncremento:          valor ENTERO, 1 para porcentaje y 2 para aumento de un valor fijo

@CategoriaListaPrecioId:  valor ENTERO que indica la categoría de lista de precios

@CategoriaProductos:      valor opcional VARCHAR donde se introduce como STRING la/s CategoriaProductoId cuyo precio 
                          se quiere actualizar en una lista separada por coma (,). Si existe un valor repetido, generará un error 
						  mediante un RISERROR.

@Productos:               Valor opcional VARCHAR donde se introduce como STRING el/los ProductoId cuyo precio se quiere
                          actualizar en una lista separada por coma (,). Si existe un valor repetido, generará un error mediante 
						  un RISERROR.

@Incremento:              Valor NUMERIC donde se define el aumento dependiendo sea porcentaje o valor de incremento fijo.

@FechaHoraDesde:          valor DATE donde se represente el inicio de vigencia de la nueva lista de precios. Esta fecha no
                          debe superponerse a una lista anterior, si esto ocurre, se debe detener la ejcución mediante 
						  la generación de error mediante RISERROR

@FechaHoraHasta:          valor opcional DATE, donde se represente el fin de vigencia de la lista de precios. Si la 
                          fecha no es introducida, dejar abierta la lista a NULL. 
*/ 

AS

DECLARE @ErrorCount INT

/******* VALIDACIONES *******/
SET @ErrorCount = 0 

IF NOT (@TipoIncremento = 1 OR @TipoIncremento = 2) OR @TipoIncremento IS NULL
	BEGIN
		 RAISERROR ( N' Error en Tipo de Incremento: INTRODUCIR (1) PARA AUMENTO PORCENTUAL O (2) PARA AUMENTO DE MONTO FIJO' , 10, 1);
		 -- 10 - severity
		 -- 1  - states
		 SET @ErrorCount = @ErrorCount + 1 
	END

IF NOT EXISTS (SELECT * 
               FROM CategoriaListaPrecios 
			   WHERE CategoriaListaPrecioId = @CategoriaListaPrecioId)

	BEGIN 
		RAISERROR (N' Error en la Categoria Lista de Precio: NO SE HA INTROUDUCIDO UNA CATEGORIA O LA MISMA NO EXISTE', 10,1 );
		SET @ErrorCount = @ErrorCount + 1
	END

IF (@FechaHoraDesde > @FechaHoraHasta                   
 OR @FechaHoraDesde <= (SELECT MIN(FechaVigenciaMinima)  
                        FROM (SELECT p.ProductoId,
						       	     MIN(lp.FechaValidezFin) AS FechaVigenciaMinima
							  FROM ListasPrecios AS lp
							  INNER JOIN Productos AS p
							  ON (lp.ProductoId = p.ProductoId)
							  WHERE p.ProductoId IN (SELECT ProdId 
							                         FROM fn_ListaIntoTabla(@Productos))                   
							  OR                                                                                   
									p.CategoriaProductoId IN (SELECT ProdId 
									                          FROM fn_ListaIntoTabla(@CategoriaProductos)) 
															  GROUP BY p.ProductoId) 
															  AS subconsulta)
 OR @FechaHoraDesde < (SELECT MAX(FechaInicio)           
                       FROM (SELECT p.ProductoId,
					       	        MAX(lp.FechaValidezInicio) AS FechaInicio
						     FROM ListasPrecios AS lp
						     INNER JOIN Productos AS p
						     ON (lp.ProductoId = p.ProductoId)
						     WHERE p.ProductoId IN (SELECT ProdId 
							                        FROM fn_ListaIntoTabla(@Productos))                   
							 OR                                                                                   
									p.CategoriaProductoId IN (SELECT ProdId 
									                          FROM fn_ListaIntoTabla(@CategoriaProductos)) 
															  GROUP BY p.ProductoId) 
															  AS subconsulta2)) 
 OR @FechaHoraDesde IS NULL                              
	BEGIN																  
		RAISERROR (N' Error en la Fecha de Inicio de Vigencia: LA FECHA SELECCIONADA ES NULA O GENERA UNA SUPERPOSICION DE LISTAS', 10,1 );
		SET @ErrorCount = @ErrorCount + 1
	END


DECLARE @tblproductos   BIGINT
DECLARE @paramproductos BIGINT

SELECT @paramproductos = COUNT(*) 
                         FROM dbo.fn_ListaIntoTabla(@Productos);

SELECT @tblproductos = COUNT(*) 
                       FROM productos 
					   WHERE ProductoId IN (SELECT ProdId 
                                            FROM dbo.fn_ListaIntoTabla(@Productos))

IF NOT (@Productos IS NULL OR @paramproductos = @tblproductos) 
	BEGIN 
		RAISERROR (N' Error en Producto: SE HA INTRODUCIDO ALGUN PRODUCTO MAS DE UNA VEZ O NO EXISTE EN EL INVENTARIO', 10,1 );
		SET @ErrorCount = @ErrorCount + 1
	END

DECLARE @tblCatproductos   BIGINT
DECLARE @paramCatproductos BIGINT

SELECT @paramCatproductos = COUNT(*) FROM dbo.fn_ListaIntoTabla(@CategoriaProductos);

SELECT @tblCatproductos = COUNT(*) FROM CategoriaProductos 
                                   WHERE CategoriaProductoId IN (SELECT ProdId 
								                                 FROM dbo.fn_ListaIntoTabla(@CategoriaProductos))

IF EXISTS (SELECT CategoriaProductoId 
		   FROM	CategoriaProductos AS p 
		   RIGHT JOIN dbo.fn_ListaIntoTabla(@CategoriaProductos) AS list
		   ON (p.CategoriaProductoId = list.ProdId) 
		   WHERE CategoriaProductoId IS NULL) 
   OR NOT (@paramCatproductos = @tblCatproductos OR @CategoriaProductos IS NULL) 
   
	BEGIN 
		RAISERROR (N' Error Categoria Producto: SE HA INTRODUCIDO ALGUNA CATEGORIA MAS DE UNA VEZ O NO EXISTE EN EL INVENTARIO', 10,1 );
		SET @ErrorCount = @ErrorCount + 1
	END

DECLARE @tabla TABLE (	ListaInternaPrecioId          BIGINT       , 
						CategoriaListaPrecioId        BIGINT       ,
						ProductoId                    BIGINT       ,
						Precio                        NUMERIC(18,4),
						PrecioReferenciaUnidadFiscal  NUMERIC(18,4),
						FechaValidezInicio            DATETIME     ,
						FechaValidezFin               DATETIME     ,
						FechaAlta                     DATETIME     ,
						CategoriaProductoid           BIGINT       ,
					    Precionuevo                   NUMERIC(18,4),
						Fechainicionuevo              DATETIME     , 
						Fechafinnuevo                 DATETIME)

IF @Incremento IS NULL
	BEGIN 
		RAISERROR (N' Error en Incremento: INGRESAR UN VALOR NO NULO', 10,1);
		SET @ErrorCount = @ErrorCount + 1
	END

/******* CREACION DE TABLA CON LOS PRODUCTOS SELECCIONADOS *******/

INSERT INTO @tabla
SELECT 
	lp.ListaInternaPrecioId        , 
	lp.CategoriaListaPrecioId      , 
	lp.ProductoId                  ,  
	lp.Precio                      , 
	lp.PrecioReferenciaUnidadFiscal, 
	lp.FechaValidezInicio          ,
	lp.FechaValidezFin             , 
	lp.FechaAlta                   ,
	p.CategoriaProductoId          ,
	0 AS Precionuevo               ,
	@FechaHoraDesde                , 
    @FechaHoraHasta    
FROM 
	ListasPrecios AS lp
INNER JOIN 
    Productos AS p
ON (lp.ProductoId = p.ProductoId)
INNER JOIN 
(SELECT 
	p.ProductoId,                                    
	MAX (lp.FechaValidezInicio)  AS FechaInicioMaximo
    FROM 
	ListasPrecios AS lp
    INNER JOIN 
    Productos AS p
    ON (lp.ProductoId = p.ProductoId)
    WHERE 
    (p.ProductoId IN (SELECT ProdId FROM fn_ListaIntoTabla(@Productos)))
	OR
	(p.CategoriaProductoId IN (SELECT ProdId FROM fn_ListaIntoTabla(@CategoriaProductos )) 
	OR 
	(@Productos IS NULL AND @CategoriaProductos IS NULL))
	GROUP BY p.ProductoId
) AS subconsulta
ON (subconsulta.ProductoId = p.ProductoId AND lp.FechaValidezInicio = subconsulta.FechaInicioMaximo)


SELECT * FROM @tabla;

/******* SI LAS VALIDACIONES FUERON EXITOSAS, CREACION DE TABLA CON PRECIOS MODIFICADOS *******/

IF @ErrorCount > 0
	BEGIN
		SELECT @ErrorCount AS 'Errores en ingreso de argumentos';
	END
ELSE
	BEGIN
		UPDATE @tabla SET Precionuevo = dbo.fn_IncrementoPrecio(Precio, @TipoIncremento, @Incremento) 
		              FROM @tabla

		UPDATE @tabla SET FechaValidezFin = DATEADD(minute, -1, CONVERT(DATETIME, @FechaHoraDesde))
					  FROM @tabla
					  WHERE FechaValidezFin IS NULL 
/* 
--sentencia para insertar los productos con su nuevo precio en la tabla ListasPrecios
		INSERT INTO ListasPrecios (CategoriaListaPrecioId, 
								   ProductoId, 
								   Precio, 
								   FechaValidezInicio, 
								   FechaValidezFin, 
								   FechaAlta)	
				            SELECT CategoriaListaPrecioId, 
						           ProductoId, 
								   Precionuevo, 
								   Fechainicionuevo, 
								   Fechafinnuevo, 
								   FechaAlta
						    FROM @tabla
*/
		SELECT * 
		FROM @tabla
	END
GO

/* 

-- Ejemplo de uso del SP

EXEC RevaluarListadePrecios
	@TipoIncremento           = 1           ,   
	@CategoriaListaPrecioId   = 1           ,   
	@CategoriaProductos       = 529	        ,
	@Productos                = 142315      ,
	@Incremento               = 20          ,
	@FechaHoraDesde           = '2023-04-15', 
	@FechaHoraHasta           = NULL
*/




