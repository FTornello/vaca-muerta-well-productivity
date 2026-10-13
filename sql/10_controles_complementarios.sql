-- Controles de las tablas que se suman al modelo central. Se corre al final:
--   psql -d vaca_muerta -f sql/10_controles_complementarios.sql
-- La columna ok tiene que dar true en todas.
--
-- Estas tablas no se enlazan todas igual. Trayectorias se une por pozo;
-- inversiones y reservas, por el nombre del área; el resto solo comparte el
-- mes. Los controles miden que esos enlaces sigan funcionando si la fuente
-- cambia un nombre o repite un período.

WITH controles (control, detalle, ok) AS (
    SELECT 'trayectorias: un pozo, una fila',
           count(*) || ' filas, ' || count(DISTINCT pozo_id) || ' pozos',
           count(*) = count(DISTINCT pozo_id)
    FROM vm.trayectoria
    UNION ALL
    SELECT 'trayectorias: largo de rama coincide con la tabla de fracturas',
           'diferencia mediana de ' || round(percentile_cont(0.5) WITHIN GROUP (ORDER BY abs(t.rama_m - f.longitud_rama_m))::numeric) || ' m',
           percentile_cont(0.5) WITHIN GROUP (ORDER BY abs(t.rama_m - f.longitud_rama_m)) < 50
    FROM vm.trayectoria t
    JOIN vm.fractura f ON f.pozo_id = t.pozo_id AND f.nro_fractura = 1
    WHERE t.rama_m IS NOT NULL AND f.longitud_rama_m > 0
    UNION ALL
    SELECT 'inversiones: al menos 95 % de los dólares cae en un área conocida',
           round(100 * sum(usd_millones) FILTER (WHERE area_id IS NOT NULL) / sum(usd_millones), 1) || ' %',
           sum(usd_millones) FILTER (WHERE area_id IS NOT NULL) / sum(usd_millones) >= 0.95
    FROM vm.inversion
    UNION ALL
    SELECT 'reservas: al menos 95 % del petróleo comprobado cae en un área conocida',
           round(100 * sum(petroleo_comprobadas) FILTER (WHERE area_id IS NOT NULL) / sum(petroleo_comprobadas), 1) || ' %',
           sum(petroleo_comprobadas) FILTER (WHERE area_id IS NOT NULL) / sum(petroleo_comprobadas) >= 0.95
    FROM vm.reserva
    UNION ALL
    SELECT 'reservas: están los nueve años, de 2017 a 2025',
           count(DISTINCT anio) || ' años',
           count(DISTINCT anio) = 9 AND min(anio) = 2017 AND max(anio) = 2025
    FROM vm.reserva
    UNION ALL
    SELECT 'precio del gas: sin meses faltantes',
           count(*) || ' meses entre ' || min(mes) || ' y ' || max(mes),
           count(*) = (extract(year FROM age(max(mes), min(mes))) * 12 + extract(month FROM age(max(mes), min(mes))) + 1)
    FROM vm.precio_gas
    UNION ALL
    SELECT 'oleoducto: sin meses faltantes desde 2020',
           count(*) || ' meses',
           count(*) = (extract(year FROM age(max(mes), DATE '2020-01-01')) * 12 + extract(month FROM age(max(mes), DATE '2020-01-01')) + 1)
    FROM vm.oleoducto_troncal
    WHERE mes >= DATE '2020-01-01'
    UNION ALL
    SELECT 'exportación: nunca supera la producción del mes',
           'máximo de ' || round(100 * max(e.volumen_m3 / p.petroleo_m3)) || ' % de la producción',
           max(e.volumen_m3 / p.petroleo_m3) < 1
    FROM (SELECT mes, sum(volumen_m3) AS volumen_m3 FROM vm.exportacion GROUP BY mes) e
    JOIN (SELECT mes, sum(petroleo_m3) AS petroleo_m3 FROM vm.produccion_mensual GROUP BY mes) p USING (mes)
    WHERE e.mes >= DATE '2022-01-01'
    UNION ALL
    SELECT 'empresas: todo lo exportado tiene un grupo empresario asignado',
           round(100 * sum(volumen_m3) FILTER (WHERE grupo IS NOT NULL) / sum(volumen_m3), 1) || ' %',
           count(*) FILTER (WHERE grupo IS NULL) = 0
    FROM vm.exportacion
    UNION ALL
    SELECT 'empresas: toda la inversión tiene un grupo empresario asignado',
           round(100 * sum(usd_millones) FILTER (WHERE grupo IS NOT NULL) / sum(usd_millones), 1) || ' %',
           count(*) FILTER (WHERE grupo IS NULL) = 0
    FROM vm.inversion
    UNION ALL
    SELECT 'regalías: la tasa efectiva de Neuquén está entre 10 % y 15 %',
           'entre ' || round(100 * min(tasa), 1) || ' % y ' || round(100 * max(tasa), 1) || ' % por año',
           min(tasa) >= 0.10 AND max(tasa) <= 0.15
    FROM (
        SELECT sum(regalias_usd) / sum(precio_usd_m3 * produccion_m3) AS tasa
        FROM vm.regalia_petroleo
        WHERE provincia = 'Neuquen' AND mes >= DATE '2014-01-01'
        GROUP BY extract(year FROM mes)
    ) por_anio
    UNION ALL
    SELECT 'declinación: el acumulado nunca baja y a los 12 meses vale 1',
           'a 12 meses: ' || round(max(acumulado_base) FILTER (WHERE mes_de_vida = 12), 3)
               || '; a 25 años: ' || round(max(acumulado_base) FILTER (WHERE mes_de_vida = 300), 2),
           bool_and(caudal_base >= 0)
               AND abs(max(acumulado_base) FILTER (WHERE mes_de_vida = 12) - 1) < 0.001
               AND bool_and(acumulado_bajo <= acumulado_base AND acumulado_base <= acumulado_alto)
    FROM vm.declinacion
    UNION ALL
    SELECT 'surtidor: están los cuatro productos en las 24 provincias todos los meses',
           count(*) || ' filas en ' || count(DISTINCT mes) || ' meses',
           count(*) = count(DISTINCT mes) * 24 * 4
    FROM vm.precio_surtidor
    UNION ALL
    SELECT 'surtidor: el precio con impuestos nunca es menor que el precio sin impuestos',
           count(*) FILTER (WHERE precio_surtidor < precio_sin_impuestos) || ' casos',
           count(*) FILTER (WHERE precio_surtidor < precio_sin_impuestos) = 0
    FROM vm.precio_surtidor
    UNION ALL
    SELECT 'comercio exterior: no falta ningún mes y 2025 cierra con el saldo que informó el INDEC',
           count(*) || ' meses; saldo de energía 2025: '
               || round(sum(exportacion_energia - importacion_energia) FILTER (WHERE extract(year FROM mes) = 2025)),
           count(*) = (extract(year FROM age(max(mes), min(mes))) * 12 + extract(month FROM age(max(mes), min(mes))) + 1)
               AND abs(sum(exportacion_energia - importacion_energia) FILTER (WHERE extract(year FROM mes) = 2025) - 7815) < 50
    FROM vm.comercio_energia
    UNION ALL
    SELECT 'país: Vaca Muerta nunca produce más petróleo ni más gas que el país entero',
           count(*) || ' meses; máximo de Vaca Muerta sobre el país: '
               || round(100 * max(v.petroleo / p.petroleo_producido_km3)) || ' % en petróleo',
           bool_and(v.petroleo <= p.petroleo_producido_km3 OR p.petroleo_producido_km3 IS NULL)
               AND bool_and(v.gas <= p.gas_producido_mm_m3 OR p.gas_producido_mm_m3 IS NULL)
    FROM vm.pais_energia p
    JOIN (SELECT mes, sum(petroleo_m3) / 1000 AS petroleo, sum(gas_miles_m3) / 1000 AS gas
          FROM vm.produccion_mensual GROUP BY mes) v USING (mes)
    UNION ALL
    SELECT 'pronósticos: las cuatro áreas históricas tienen los cinco años en el informe de 2025',
           count(*) || ' filas de ' || count(DISTINCT area_id) || ' áreas',
           count(*) = 20 AND count(DISTINCT area_id) = 4
    FROM vm.pronostico_petroleo p
    JOIN vm.area a USING (area_id)
    WHERE p.anio_informe = 2025
      AND a.nombre IN ('LOMA CAMPANA', 'LA AMARGA CHICA', 'BANDURRIA SUR', 'BAJADA DEL PALO OESTE')
    UNION ALL
    SELECT 'venteo: las detecciones de Neuquén caen dentro de la provincia y tienen distancia calculada',
           count(*) || ' detecciones, ' || count(km_al_pozo) || ' con un pozo a menos de unos 10 km',
           bool_and(latitud BETWEEN -41.5 AND -36 AND longitud BETWEEN -71.5 AND -67.5)
               AND count(km_al_pozo) > 0.8 * count(*)
    FROM vm.venteo_detectado
    WHERE provincia = 'NEUQUEN'
    UNION ALL
    SELECT 'metros perforados: desde 2021 dan entre 5 y 7 km por cada pozo de Vaca Muerta que arranca',
           string_agg(anio || ': ' || round(metros / pozos), ', ' ORDER BY anio),
           bool_and(metros / pozos BETWEEN 5000 AND 7000)
    FROM (
        SELECT extract(year FROM m.mes)::integer AS anio, sum(m.metros) AS metros,
               (SELECT count(*) FROM vm.pozo p
                WHERE extract(year FROM p.primer_mes_produccion) = extract(year FROM min(m.mes))) AS pozos
        FROM vm.metros_perforados m
        WHERE m.provincia LIKE 'Neuqu%' AND m.mes BETWEEN DATE '2021-01-01' AND DATE '2025-12-01'
        GROUP BY 1
    ) por_anio
    UNION ALL
    SELECT 'refinación: el crudo procesado por refinería suma lo mismo que la serie del país (2024)',
           'por refinería: ' || round(c.m3 / 1000) || ' miles de m3; serie del país: ' || round(p.km3),
           abs(c.m3 / 1000 / p.km3 - 1) < 0.03
    FROM (SELECT sum(m3) AS m3 FROM vm.crudo_procesado WHERE extract(year FROM mes) = 2024) c,
         (SELECT sum(petroleo_procesado_km3) AS km3 FROM vm.pais_energia WHERE extract(year FROM mes) = 2024) p
    UNION ALL
    SELECT 'pronóstico de gas: el informe de 2025 trae los cuatro años siguientes y casi todas las áreas tienen nombre',
           count(DISTINCT anio_pronostico) FILTER (WHERE tipo = 'Totales Anuales') || ' años; '
               || round(100.0 * count(area_nombre) / count(*)) || ' % de las filas con nombre de área',
           count(DISTINCT anio_pronostico) FILTER (WHERE tipo = 'Totales Anuales') = 4
               AND count(area_nombre) > 0.9 * count(*)
    FROM vm.pronostico_gas
    WHERE anio_informe = 2025
    UNION ALL
    SELECT 'pozos terminados y puntos de venteo: hay datos de Neuquén',
           (SELECT count(*) FROM vm.venteo_punto_declarado WHERE latitud BETWEEN -41.5 AND -36 AND longitud BETWEEN -71.5 AND -67.5)
               || ' puntos declarados en la zona; ' || count(DISTINCT mes) || ' meses de pozos terminados',
           count(DISTINCT mes) >= 200
               AND (SELECT count(*) FROM vm.venteo_punto_declarado WHERE latitud BETWEEN -41.5 AND -36 AND longitud BETWEEN -71.5 AND -67.5) > 500
    FROM vm.pozos_terminados
    WHERE provincia LIKE 'Neuqu%'
    UNION ALL
    SELECT 'Brent: no falta ningún mes desde 2010 y el precio está en un rango razonable',
           count(*) || ' meses, entre ' || round(min(usd_bbl)) || ' y ' || round(max(usd_bbl)) || ' USD por barril',
           count(*) = (extract(year FROM age(max(mes), min(mes))) * 12 + extract(month FROM age(max(mes), min(mes))) + 1)
               AND min(usd_bbl) > 10 AND max(usd_bbl) < 200
    FROM vm.brent
    WHERE mes >= DATE '2010-01-01'
    UNION ALL
    SELECT 'Henry Hub: cubre todos los meses que tiene el precio del gas local',
           count(h.mes) || ' de ' || count(*) || ' meses',
           count(h.mes) = count(*)
    FROM vm.precio_gas g
    LEFT JOIN vm.henry_hub h USING (mes)
    UNION ALL
    SELECT 'shale de Estados Unidos: están las diez cuencas todos los meses',
           count(*) || ' filas, ' || count(DISTINCT cuenca) || ' cuencas, hasta ' || to_char(max(mes), 'YYYY-MM'),
           count(DISTINCT cuenca) = 10 AND count(*) = 10 * count(DISTINCT mes)
    FROM vm.eeuu_tight_oil
    UNION ALL
    SELECT 'proyección de la base: proyectar un año con la curva de vida erra menos de 15 % contra lo que pasó',
           string_agg(anio || ': ' || round(100 * (proyectado / real - 1)) || ' %', ', ' ORDER BY anio),
           bool_and(abs(proyectado / real - 1) < 0.15)
    FROM (
        SELECT b.anio,
               sum(b.kbd * d2.caudal_base / d1.caudal_base) AS proyectado,
               sum(pm.petroleo_m3 * 6.2898 / 31 / 1000)     AS real
        FROM (
            SELECT y.anio, pm0.pozo_id, pm0.petroleo_m3 * 6.2898 / 31 / 1000 AS kbd,
                   greatest((extract(year FROM age(make_date(y.anio, 12, 1), po.primer_mes_produccion)) * 12
                           + extract(month FROM age(make_date(y.anio, 12, 1), po.primer_mes_produccion)))::integer + 1, 4) AS edad
            FROM generate_series(2020, 2024) AS y(anio)
            JOIN vm.produccion_mensual pm0 ON pm0.mes = make_date(y.anio, 12, 1) AND pm0.petroleo_m3 > 0
            JOIN vm.pozo po USING (pozo_id)
        ) b
        JOIN vm.declinacion d1 ON d1.mes_de_vida = least(b.edad, 288)
        JOIN vm.declinacion d2 ON d2.mes_de_vida = least(b.edad, 288) + 12
        LEFT JOIN vm.produccion_mensual pm ON pm.pozo_id = b.pozo_id AND pm.mes = make_date(b.anio + 1, 12, 1)
        GROUP BY 1
    ) por_anio
    UNION ALL
    SELECT 'empleo: sin filas repetidas por mes, departamento y sector',
           count(*) || ' filas',
           count(*) = count(DISTINCT (mes, departamento, sector))
    FROM vm.empleo_neuquen
)
SELECT control, detalle, ok FROM controles;
