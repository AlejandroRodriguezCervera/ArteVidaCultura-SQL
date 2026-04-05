/* ------------------------------------------------------------------------------------------------
DEFINICIÓN DE LA ESTRUCTURA DE LA BASE DE DATOS
Se crean las tablas, claves primarias, claves foráneas y restricciones de dominio
según el modelo entidad–relación definido previamente.
--------------------------------------------------------------------------------------------------*/

DROP DATABASE IF EXISTS ArteVidaCultura;
CREATE DATABASE ArteVidaCultura;
USE ArteVidaCultura;
create table persona (
idPersona varchar(3) primary key, -- Clave primaria.
nombreP varchar(40), -- Nombre de la persona.
ap1 varchar(40), -- Primer apellido.
ap2 varchar(40), -- Segundo apellido.
email varchar(50) check (email REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$') 
      -- Restricción de dominio para garantizar un formato válido de email.
);
create table telefono (
numTel varchar(9) not null check(numTel REGEXP '^[0-9]{9}$') primary key, 
	  -- Check de que los teléfonos tengan 9 cifras
idPersona varchar(3), -- Clave foránea
foreign key (idPersona) references persona(idPersona) on delete cascade on update cascade 
      -- borra los teléfonos de la persona si se borra dicha persona
);   
create table actividades (
idAct varchar(3) primary key, -- Clave primaria
nomAct varchar(80) unique key, -- El nombre de la actividad debe ser único.
tipo varchar(40) -- Tipo de la actividad.
);
create table ubicacion (
idUbicacion varchar(3) primary key, -- Clave primaria de la tabla
nombreUbi varchar(40) unique key, -- El nombre de la Ubicación debe ser único.
direccion varchar(50),
tipoUbi varchar(30), -- Ciudad o pueblo de la ubicación.
aforo integer not null check( aforo >0), -- Check para ver que el aforo no sea nulo.
precioAlq numeric(8,2) not null, -- Precio de alquiler de la ubicación.
caract varchar(100) -- Características de la ubicación.
);
create table eventos (
idEvento varchar(3) primary key, -- Clave primaria.
nombEvento varchar(80), -- Nombre del evento.
idUbicacion varchar(3), -- Clave foránea.
fecha date not null,
hora time not null,
precioEv numeric(6,2) not null, -- Precio de la entrada al evento.
idAct varchar(3) , -- Clave foránea.
descripEv varchar(100), -- Descripción del evento.
foreign key(idUbicacion) references ubicacion(idUbicacion) on delete cascade on update cascade,
foreign key(idAct) references actividades(idAct) on delete cascade on update cascade,
unique key(idUbicacion, fecha, hora)
);
create table artista (
idPersona varchar(3) primary key, 
        -- Clave primaria y clave foránea:
        -- identifica de forma única al artista y lo vincula con la entidad persona
nomArt varchar(30) unique key, -- Nombre del artista como clave única.
biblioArt varchar(100), -- Bibliografía del artista.
foreign key (idPersona) references  persona(idPersona) on delete cascade on update cascade
);
create table asistente(
idPersona varchar(3) , 
idEvento varchar (3),
    -- Claves primarias de la tabla. 
valoracion int null check (valoracion between 0 and 5),
-- Valoración del 0 al 5, permitiendo que sea nula (puede que el evento no se haya realizado aún).
primary key(idPersona, idEvento), 
foreign key(idPersona) references persona(idPersona) on delete cascade on update cascade,
foreign key(idEvento) references eventos(idEvento) on delete cascade on update cascade
);
create table participa (
idPersona varchar(3),
idEvento varchar(3),
   -- Claves primarias de la tabla.
pago_Art numeric(8,2) check (pago_Art > 0),
-- Pago del artista (no puede ser nulo ni 0).
primary key(idEvento, idPersona),
    foreign key(idEvento) references eventos(idEvento) on delete cascade on update cascade,
    foreign key(idPersona) references artista(idPersona) on delete cascade on update cascade
);

/* ------------------------------------------------------------------------------------------------
TRIGGERS
Se definen triggers para garantizar reglas de negocio que no pueden
expresarse únicamente mediante restricciones SQL estándar.
--------------------------------------------------------------------------------------------------*/

-- Trigger que checkea el aforo al añadir un nuevo asistente a un evento

delimiter $$
create trigger cumplir_aforo
before insert on asistente
for each row
begin
    declare numAsistentes int;
    declare maxAforo int;

    -- Número actual de asistentes al evento
    select COUNT(*)  into numAsistentes
    from asistente
    where idEvento = new.idEvento;

    -- Aforo máximo del evento
    select aforo into maxAforo
    from eventos e inner join ubicacion u on e.idUbicacion = u.idUbicacion
    where e.idEvento = new.idEvento;

    if numAsistentes + 1 > maxAforo then
        signal sqlstate '45000'
        set message_text = 'No se puede superar el aforo de la ubicación';
    end if;
end $$
delimiter ;


-- Trigger que controla el aforo cuando se modifica la ubicación de un evento.
-- Garantiza que el número actual de asistentes no supere el aforo de la nueva ubicación

delimiter $$
create trigger check_aforo_cambio_ubicacion
before update on eventos
for each row
begin
    declare numasistentes int;
    declare aforo_max int;
    if new.idUbicacion <> old.idUbicacion then
        select count(*)
        into numasistentes
        from asistente
        where idEvento = new.idEvento;
        select aforo
        into aforo_max
        from ubicacion
        where idubicacion = new.idubicacion;
        if numasistentes > aforo_max then
            signal sqlstate '45000'
            set message_text = 'No se puede mover el evento a una ubicacion con aforo insuficiente';
        end if;

    end if;
end $$

delimiter ;


-- Trigger para evitar que un artista vaya a dos eventos en la misma fecha y hora
delimiter $$
create trigger artista_no_doble_evento
before insert on participa
for each row
begin
    if exists (
        select 1
        from participa p
        join eventos e1 on p.idEvento = e1.idEvento
        join eventos e2 on e2.idEvento = new.idEvento
        where p.idPersona = new.idPersona
          and e1.fecha = e2.fecha
          and e1.hora = e2.hora
    ) then
        signal sqlstate '45000'
        set message_text = 'El artista ya participa en otro evento en la misma fecha y hora';
    end if;
end $$

delimiter ;

-- Trigger para evitar que exista una valoración si todavía no ha sucedido el evento.alter

delimiter $$
create trigger valoracion_solo_despues_evento
before insert on asistente
for each row
begin
    declare fecha_evento date;

    if new.valoracion is not null then
        select fecha into fecha_evento
        from eventos
        where idEvento = new.idEvento;

        if fecha_evento > curdate() then
            signal sqlstate '45000'
            set message_text = 'No se puede valorar un evento que aún no ha ocurrido';
        end if;
    end if;
end $$

delimiter ;

-- Vista 
create view resumen_eventos as
select 
    e.idEvento,
    e.nombEvento,
    u.nombreUbi        as ubicacion,
    a.nomAct           as actividad,
    e.fecha,
    e.precioEv,
    COUNT(distinct as2.idPersona)              as num_asistentes,
    ROUND(avg(as2.valoracion), 2)              as valoracion_media,
    COUNT(distinct as2.idPersona) * e.precioEv as recaudacion_estimada
from eventos e
inner join ubicacion u  on e.idUbicacion = u.idUbicacion
inner join actividades a on e.idAct      = a.idAct
left join  asistente as2 on e.idEvento   = as2.idEvento
group by e.idEvento;

/* ------------------------------------------------------------------------------------------------
INSERCIÓN DE DATOS
Se insertan datos de prueba suficientes para comprobar el correcto
funcionamiento de las restricciones, triggers y consultas.
--------------------------------------------------------------------------------------------------*/

-- Inserción de personas

insert into persona (idPersona, nombreP, ap1, ap2, email) values
('001','María','González','López','maria1@email.com'),
('002','Juan','Martínez','Pérez','juan2@email.com'),
('003','Ana','Ramírez','Sánchez','ana3@email.com'),
('004','Luis','Fernández','Torres','luis4@email.com'),
('005','Sofía','Hernández','Gómez','sofia5@email.com'),
('006','Carlos','García','Vega','carlos6@email.com'),
('007','Elena','Díaz','Moreno','elena7@email.com'),
('008','Pedro','Ruiz','Navarro','pedro8@email.com'),
('009','Lucía','Santos','Iglesias','lucia9@email.com'),
('010','Diego','Castillo','Ortega','diego10@email.com'),
('011','Marcos','Vega','Lara','marcos11@email.com'),
('012','Isabel','Ramos','Morales','isabel12@email.com'),
('013','Javier','Ortiz','Suárez','javier13@email.com'),
('014','Clara','Torres','Gil','clara14@email.com'),
('015','Antonio','Molina','Pérez','antonio15@email.com'),
('016','Patricia','Romero','Sánchez','patricia16@email.com'),
('017','David','Gómez','García','david17@email.com'),
('018','Sandra','Díaz','Martínez','sandra18@email.com'),
('019','Miguel','Santos','López','miguel19@email.com'),
('020','Laura','Hernández','Navarro','laura20@email.com'),
('021','Fernando','Rojas','Cabrera','fernando21@email.com'),
('022','Alejandra','López','Martínez','alejandra22@email.com'),
('023','Ricardo','Méndez','Vega','ricardo23@email.com'),
('024','Natalia','Suárez','García','natalia24@email.com'),
('025','Pablo','Moreno','Torres','pablo25@email.com'),
('026','Carla','González','Ramos','carla26@email.com'),
('027','Víctor','Fernández','Gil','victor27@email.com'),
('028','Marta','Castillo','Santos','marta28@email.com'),
('029','Raúl','Hernández','López','raul29@email.com'),
('030','Cristina','Díaz','Navarro','cristina30@email.com'),
('031','Alberto','Ramírez','Pérez','alberto31@email.com'),
('032','Silvia','Gómez','Morales','silvia32@email.com'),
('033','Jorge','Torres','Ramos','jorge33@email.com'),
('034','Paula','Molina','Suárez','paula34@email.com'),
('035','Sergio','Hernández','Vega','sergio35@email.com'),
('036','Mónica','López','Gil','monica36@email.com'),
('037','Iván','Castillo','Martínez','ivan37@email.com'),
('038','Lorena','Ramírez','Torres','lorena38@email.com'),
('039','Alma','Díaz','Rojas','alma39@email.com'),
('040','Héctor','García','Santos','hector40@email.com'),
('041','Gabriela','Fernández','Navarro','gabriela41@email.com'),
('042','Francisco','Gómez','Vega','francisco42@email.com'),
('043','Natalia','Santos','Pérez','natalia43@email.com'),
('044','Andrés','Ramos','Martínez','andres44@email.com'),
('045','Lucía','Torres','García','lucia45@email.com'),
('046','Ricardo','Molina','Suárez','ricardo46@email.com'),
('047','Sara','Hernández','López','sara47@email.com'),
('048','Javier','Díaz','Navarro','javier48@email.com'),
('049','Verónica','Ramírez','Gil','veronica49@email.com'),
('050','Diego','García','Torres','diego50@email.com'),
('051','Alba','García','López','alba51@email.com'),
('052','Marcelo','Fernández','Pérez','marcelo52@email.com'),
('053','Claudia','Ramírez','Gómez','claudia53@email.com'),
('054','Hugo','Martínez','Torres','hugo54@email.com'),
('055','Lorena','Díaz','Santos','lorena55@email.com'),
('056','Iván','Rojas','Navarro','ivan56@email.com'),
('057','Elena','Molina','Suárez','elena57@email.com'),
('058','Raúl','Gómez','Martínez','raul58@email.com'),
('059','Paula','García','Torres','paula59@email.com'),
('060','Jorge','López','Hernández','jorge60@email.com'),
('061','Marta','Santos','Pérez','marta61@email.com'),
('062','Diego','Romero','García','diego62@email.com'),
('063','Natalia','Vega','López','natalia63@email.com'),
('064','Fernando','Ramos','Torres','fernando64@email.com'),
('065','Isabel','Moreno','Pérez','isabel65@email.com'),
('066','David','Gómez','Navarro','david66@email.com'),
('067','Sara','Castillo','Martínez','sara67@email.com'),
('068','Luis','Hernández','Santos','luis68@email.com'),
('069','Carla','López','García','carla69@email.com'),
('070','Iván','Ramírez','Vega','ivan70@email.com'),
('071','Ana','Torres','Suárez','ana71@email.com'),
('072','Pablo','García','López','pablo72@email.com'),
('073','Lucía','Fernández','Martínez','lucia73@email.com'),
('074','Ricardo','Santos','Gómez','ricardo74@email.com'),
('075','Mónica','Ramírez','Torres','monica75@email.com'),
('076','Javier','Hernández','Pérez','javier76@email.com'),
('077','Elena','Díaz','García','elena77@email.com'),
('078','Alberto','Ramos','López','alberto78@email.com'),
('079','Clara','Gómez','Torres','clara79@email.com'),
('080','Sergio','López','Navarro','sergio80@email.com'),
('081','Natalia','Moreno','Pérez','natalia81@email.com'),
('082','Héctor','Santos','García','hector82@email.com'),
('083','Gabriela','Ramírez','Torres','gabriela83@email.com'),
('084','Diego','Fernández','López','diego84@email.com'),
('085','Paula','García','Martínez','paula85@email.com'),
('086','Iván','Hernández','Santos','ivan86@email.com'),
('087','Alma','López','Gómez','alma87@email.com'),
('088','Luis','Ramos','Navarro','luis88@email.com'),
('089','Elena','Santos','Torres','elena89@email.com'),
('090','Miguel','García','López','miguel90@email.com'),
('091','Lorena','Ramírez','Martínez','lorena91@email.com'),
('092','Javier','Fernández','Gómez','javier92@email.com'),
('093','Cristina','López','Torres','cristina93@email.com'),
('094','Raúl','Santos','Pérez','raul94@email.com'),
('095','Sofía','García','Navarro','sofia95@email.com'),
('096','Alberto','Ramírez','Torres','alberto96@email.com'),
('097','Clara','Hernández','Gómez','clara97@email.com'),
('098','Pablo','Díaz','Santos','pablo98@email.com'),
('099','Lucía','Ramos','López','lucia99@email.com'),
('100','Diego','García','Martínez','diego100@email.com');

-- Inserción de teléfonos de contacto de las personas

insert into telefono (numTel, idPersona) values
('600000001','001'),('600000002','001'),
('600000003','002'),
('600000004','003'),('600000005','003'),
('600000006','004'),
('600000007','005'),('600000008','005'),
('600000009','006'),
('600000010','007'),
('600000011','008'),('600000012','008'),
('600000013','009'),
('600000014','010'),
('600000015','011'),
('600000016','012'),('600000017','012'),
('600000018','013'),
('600000019','014'),
('600000020','015'),
('600000021','016'),('600000022','016'),
('600000023','017'),
('600000024','018'),
('600000025','019'),
('600000026','020'),
('600000027','021'),
('600000028','022'),
('600000029','023'),
('600000030','024'),
('600000031','025'),
('600000032','026'),
('600000033','027'),
('600000034','028'),
('600000035','029'),
('600000036','030'),
('600000037','031'),
('600000038','032'),
('600000039','033'),
('600000040','034'),
('600000041','035'),
('600000042','036'),
('600000043','037'),
('600000044','038'),
('600000045','039'),
('600000046','040'),
('600000047','041'),
('600000048','042'),
('600000049','043'),
('600000050','044'),
('645045001','045'),
('645045002','045'), 
('645046001','046'),
('645047001','047'),
('645048001','048'),
('645049001','049'),
('645050001','050'),
('645051001','051'),
('645052001','052'),
('645053001','053'),
('645054001','054'),
('645055001','055'),
('645056001','056'),
('645057001','057'),
('645058001','058'),
('645059001','059'),
('645060001','060'),
('645061001','061'),
('645062001','062'),
('645063001','063'),
('645064001','064'),
('645065001','065'),
('645066001','066'),
('645067001','067'),
('645068001','068'),
('645069001','069'),
('645070001','070'),
('645071001','071'),
('645072001','072'),
('645073001','073'),
('645074001','074'),
('645075001','075'),
('645076001','076'),
('645077001','077'),
('645078001','078'),
('645079001','079'),
('645080001','080'),
('645081001','081'),
('645082001','082'),
('645083001','083'),
('645084001','084'),
('645085001','085'),
('645086001','086'),
('645087001','087'),
('645088001','088'),
('645089001','089'),
('645090001','090'),
('645091001','091'),
('645092001','092'),
('645093001','093'),
('645094001','094'),
('645095001','095'),
('645096001','096'),
('645097001','097'),
('645098001','098'),
('645099001','099'),
('645100001','100');

-- Inserción de las actividades y sus atributos

insert into actividades (idAct, nomAct, tipo) values
('001','Concierto Clásico de Primavera','Concierto Clásica'),
('002','Festival de Jazz Urbano','Concierto Jazz'),
('003','Exposición Modernista de Pintura','Exposición'),
('004','Obra de Teatro Hamlet','Teatro'),
('005','Conferencia Innovación Tecnológica','Conferencia'),
('006','Concierto Reggaeton Summer','Concierto Reggaeton'),
('007','Exposición Escultura Contemporánea','Exposición'),
('008','Obra de Teatro Romeo y Julieta','Teatro'),
('009','Concierto Blues Night','Concierto Blues'),
('010','Conferencia Arte Digital','Conferencia'),
('011','Concierto Rock Classics','Concierto Rock and Roll'),
('012','Festival Góspel Internacional','Concierto Góspel'),
('013','Exposición Fotografía Urbana','Exposición'),
('014','Obra de Teatro La Casa de Bernarda Alba','Teatro'),
('015','Concierto Pop Hits','Concierto Pop'),
('016','Conferencia Literatura Moderna','Conferencia'),
('017','Concierto Jazz & Soul','Concierto Jazz'),
('018','Exposición Arte Vanguardista','Exposición'),
('019','Obra de Teatro El Método Grönholm','Teatro'),
('020','Concierto Country Nights','Concierto Country'),
('021','Festival de Música Electrónica','Concierto Electrónica'),
('022','Conferencia Historia del Arte','Conferencia'),
('023','Concierto Latin Beats','Concierto Salsa/Latino'),
('024','Exposición Surrealismo','Exposición'),
('025','Obra de Teatro Macbeth','Teatro');

-- Inserción de las ubicaciones y sus atributos.

insert into ubicacion (idUbicacion, nombreUbi, direccion, tipoUbi, aforo, precioAlq, caract) values
('001','Teatro María Guerrero','Calle Falsa 123','Madrid',100,500.00,'Con aire acondicionado'),
('002','Estadio Santiago Bernabeu','Av. Concierto 7','Madrid',1000,5000.00,'Pantalla gigante y césped'),
('003','Sala de Exposiciones Centro','Plaza Central 5','Barcelona',50,300.00,'Iluminación LED'),
('004','Auditorio Principal','Av. Cultura 10','Valencia',200,800.00,'Sonido profesional'),
('005','Teatro Real','Calle Mayor 1','Sevilla',250,600.00,'Aforo VIP y acústica excelente'),
('006','Teatro Cervantes','Plaza de las Artes 4','Málaga',120,450.00,'Escenario con telón rojo'),
('007','Palacio de Congresos','Av. del Congreso 12','Madrid',500,1500.00,'Aire acondicionado y proyector'),
('008','Sala Jazz Barceloneta','Calle Mar 22','Barcelona',80,400.00,'Escenario pequeño y barra de bebidas'),
('009','Auditorio Ciudad de Sevilla','Av. Cultura 5','Sevilla',300,1000.00,'Sonido surround y escenario amplio'),
('010','Teatro Principal Valencia','Calle Teatro 10','Valencia',150,550.00,'Butacas cómodas y buena acústica'),
('011','Estadio Olímpico Granada','Av. Deportes 1','Granada',1200,6000.00,'Pantalla gigante y césped artificial'),
('012','Sala de Conciertos Málaga','Calle Música 8','Málaga',90,350.00,'Iluminación profesional y escenario amplio'),
('013','Centro Cultural Bilbao','Plaza Cultura 2','Bilbao',200,700.00,'Aforo medio, acústica estándar'),
('014','Teatro Municipal Zaragoza','Calle Teatro 15','Zaragoza',180,500.00,'Escenario amplio y luces LED'),
('015','Auditorio Palacio de la Música','Av. Melodía 3','Barcelona',220,900.00,'Gran escenario y sonido profesional');

-- Inserción de los eventos y sus atributos. 

insert into eventos (idEvento, nombEvento, idUbicacion, fecha, hora, precioEv, idAct, descripEv) values
('001','VI festival de música clásica de Alcobendas','001','2026-03-15','19:00:00',20.00,'001','Concierto con la Orquesta Sinfónica'),
('002','Jazz Summer Nights en Bernabeu','002','2026-06-10','21:00:00',50.00,'002','Festival de Jazz urbano'),
('003','Exposición Modernista en Sala Centro','003','2026-04-01','17:00:00',10.00,'003','Muestra de pintura modernista'),
('004','Obra de Teatro Hamlet en Auditorio','004','2026-05-20','20:00:00',15.00,'004','Representación completa de Hamlet'),
('005','Conferencia Innovación 2026','005','2026-07-05','18:30:00',25.00,'005','Conferencia sobre avances tecnológicos'),
('006','Concierto Reggaeton Summer en Teatro Guerrero','001','2026-08-12','22:00:00',30.00,'006','Noche de reggaeton con DJs invitados'),
('007','Exposición Escultura Contemporánea','007','2026-03-15','16:00:00',12.00,'007','Exposición de esculturas modernas'),
('008','Obra de Teatro Romeo y Julieta','008','2026-05-01','19:30:00',18.00,'008','Representación de la obra clásica de Shakespeare'),
('009','Concierto Blues Night','009','2026-06-22','21:00:00',20.00,'009','Noche de blues con artistas locales'),
('010','Conferencia Arte Digital','010','2026-07-10','18:00:00',22.00,'010','Charla sobre tendencias en arte digital'),
('011','Concierto Rock Classics','011','2026-03-28','20:30:00',35.00,'011','Concierto de rock de clásicos internacionales'),
('012','Festival Góspel Internacional','012','2026-06-15','19:00:00',40.00,'012','Música góspel de distintos países'),
('013','Exposición Fotografía Urbana','013','2026-04-20','17:00:00',12.00,'013','Muestra de fotografía urbana contemporánea'),
('014','Obra de Teatro La Casa de Bernarda Alba','014','2026-05-25','20:00:00',18.00,'014','Representación de Lorca'),
('015','Concierto Pop Hits','015','2026-08-05','21:00:00',28.00,'015','Éxitos pop de todos los tiempos'),
('016','Concierto Clásico de Primavera II','002','2026-09-10','19:00:00',22.00,'001','Segunda edición del concierto clásico'), 
('017','Jazz Summer Nights Reloaded','003','2026-09-12','21:00:00',50.00,'002','Segunda edición del festival de Jazz'),
('018','Exposición Modernista II','004','2026-10-01','17:00:00',12.00,'003','Nueva exposición de pintura modernista'),
('019','Obra de Teatro Hamlet Reloaded','005','2026-10-15','20:00:00',16.00,'004','Segunda representación de Hamlet'),
('020','Conferencia Innovación Avanzada','006','2026-11-05','18:30:00',27.00,'005','Continuación de la conferencia tecnológica');

-- Inserción de los artistas.

insert into artista (idPersona, nomArt, biblioArt) values
('001','María Keys','Pianista con 10 años de experiencia en conciertos de música clásica'),
('002','Juan Arte','Artista visual especializado en modernismo y exposiciones internacionales'),
('003','Ana Jazz','Cantante y compositora de pop y jazz'),
('004','Luis Actor','Actor principal de teatro clásico y moderno'),
('005','Sofía Stone','Escultora contemporánea con exposiciones en varias ciudades'),
('006','Carlos Sax','Saxofonista reconocido internacionalmente en festivales de jazz'),
('007','Elena Pixel','Investigadora y conferenciante en arte digital'),
('008','Pedro Strings','Guitarrista de jazz con múltiples grabaciones'),
('009','Lucía Stage','Bailarina de teatro contemporáneo y clásico'),
('010','DJ Diego','DJ y productor de música electrónica'),
('011','Marta Gospel','Cantante de góspel y coros internacionales'),
('012','Ricardo Maestro','Pianista y director de orquesta'),
('013','Natalia Hamlet','Actriz de teatro con experiencia en Shakespeare'),
('014','Pablo Blues','Guitarrista de blues y rock clásico'),
('015','Carla Performance','Artista de performance y artes visuales'),
('016','Víctor Scene','Actor y director teatral'),
('017','Mónica Soul','Cantante de música pop y soul'),
('018','Iván Violin','Violinista especializado en música clásica y jazz'),
('019','Lorena Diseño','Escenógrafa y diseñadora de exposiciones'),
('020','Alma Lens','Fotógrafa urbana con exposiciones internacionales'),
('021','Héctor Keys','Compositor y pianista de música contemporánea'),
('022','Gabriela Stage','Actriz de teatro y cine independiente'),
('023','Francisco Beat','Baterista y percusionista de jazz y rock'),
('024','Andrés Latino','Cantante de música latina y salsa'),
('025','Lucía Dance','Coreógrafa y bailarina de teatro musical');

-- Inserción de la participación de artistas.

insert into participa (idEvento, idPersona, pago_Art) values
('001','001',200.00),
('001','003',180.00),
('002','006',250.00),
('002','008',150.00),
('003','002',150.00),
('003','005',200.00),
('004','004',300.00),
('004','009',220.00),
('005','007',250.00),
('005','010',180.00),
('006','003',200.00),
('006','012',220.00),
('007','005',180.00),
('007','015',200.00),
('008','004',250.00),
('008','009',220.00),
('009','014',180.00),
('009','023',200.00),
('010','007',220.00),
('010','017',200.00),
('011','012',250.00),
('011','001',200.00),
('012','011',220.00),
('012','017',180.00),
('013','020',150.00),
('013','002',180.00),
('014','016',200.00),
('014','013',220.00),
('015','017',200.00),
('015','003',180.00),
('016','001',200.00),
('016','012',220.00),
('017','006',250.00),
('017','008',150.00),
('018','002',150.00),
('018','005',200.00),
('019','004',300.00),
('019','009',220.00),
('020','007',250.00),
('020','010',180.00);

-- Inserción de los asistentes de los eventos.

insert into asistente (idPersona, idEvento, valoracion) values
('001','001',5),
('002','001',4),
('003','002',null),
('004','002',5),
('005','003',null),
('006','003',3),
('007','004',null),
('008','004',5),
('009','005',4),
('010','005',5),
('011','006',null),
('012','006',4),
('013','007',3),
('014','007',5),
('015','008',null),
('016','008',4),
('017','009',5),
('018','009',3),
('019','010',4),
('020','010',null),
('021','011',5),
('022','011',3),
('023','012',null),
('024','012',4),
('025','013',5),
('026','013',null),
('027','014',3),
('028','014',5),
('029','015',null),
('030','015',4),
('031','016',5),
('032','016',3),
('033','017',4),
('034','017',null),
('035','018',5),
('036','018',3),
('037','019',null),
('038','019',4),
('039','020',5),
('040','020',3),
('041','001',null),
('042','002',5),
('043','003',4),
('044','004',null),
('045','005',5),
('046','006',3),
('047','007',4),
('048','008',null),
('049','009',5),
('050','010',4),
('051','011',null),
('052','012',3),
('053','013',5),
('054','014',null),
('055','015',4),
('056','016',5),
('057','017',3),
('058','018',null),
('059','019',4),
('060','020',5),
('061','001',4),
('062','002',3),
('063','003',5),
('064','004',null),
('065','003',4),
('066','003',5),
('067','003',3),
('068','003',null),
('069','003',4),
('070','003',5),
('071','003',3),
('072','003',null),
('073','003',4),
('074','003',5),
('075','003',null);

/* ------------------------------------------------------------------------------------------------
CONSULTAS, MODIFICACIONES, BORRADOS Y VISTAS
Consultas de distinto nivel de complejidad para el análisis de la actividad
cultural, participación, rentabilidad y valoración de eventos.
--------------------------------------------------------------------------------------------------*/

-- Consulta 1
-- Número de eventos en los que se ha realizado cada actividad.

select a.idAct, nomAct nombre_actividad, count(e.idEvento)
from actividades a left join eventos e on a.idAct=e.idAct
group by idAct;

-- Consulta 2
-- Fecha en la que se han realizado más eventos.

select fecha,count(idEvento) num_eventos
from eventos 
group by fecha
having count(idEvento) = ( select max(num_eventos)
						   from( select count(idEvento) num_eventos
								 from eventos
							     group by fecha
                                 )  conteo
                        
);

-- Consulta 3
-- Eventos con aforo que haya superado el 20% del aforo


select e.idEvento, e.nombEvento,
       count(a.idPersona)  asistentes,
       u.aforo,
       round(count(a.idPersona) / u.aforo * 100, 2)  porcentaje_ocupacion
from eventos e inner join ubicacion u on e.idUbicacion = u.idUbicacion
left join asistente a on e.idEvento = a.idEvento
group by e.idEvento
having porcentaje_ocupacion >= 20;

-- Consulta 4
-- Artistas que han participado en más eventos que la media.

select ar.nomArt, count(p.idEvento)  total_eventos
from artista ar inner join participa p on ar.idPersona = p.idPersona
group by ar.idPersona
having count(p.idEvento) > (select avg(num_eventos)
                             from( select count(*) as num_eventos
                                   from participa
								   group by idPersona
                                    ) t
);

-- Consulta 5
-- Eventos con más valoración que la media (solo si hay 3 valoraciones o más).

select e.nombEvento,
       round(avg(a.valoracion),2)  valoracion_media,
       count(a.valoracion) total_valoraciones
from eventos e inner join asistente a on e.idEvento = a.idEvento
where a.valoracion is not null
group by e.idEvento
having count(a.valoracion) >= 3
order by valoracion_media desc;

-- Consulta 6
-- Artista mejor pagado por evento. 

select nomArt, nombEvento, pago_Art
from (select ar.nomArt, e.nombEvento, p.pago_Art,
	  rank() over (partition by e.idEvento order by p.pago_Art desc)  ranking
	  from participa p inner join artista ar on p.idPersona = ar.idPersona
      inner join eventos e on p.idEvento = e.idEvento
) t
where ranking = 1;

-- Consulta 7
-- Coste de artistas frente a la recaudación estimada.

select e.nombEvento,
       sum(p.pago_Art) coste_artistas,
       count(a.idPersona) * e.precioEv  recaudacion_estimada
from eventos e inner join participa p on e.idEvento = p.idEvento
left join asistente a on e.idEvento = a.idEvento
group by e.idEvento
having coste_artistas > recaudacion_estimada;

-- Consulta 8
-- Personas con que han sido tanto asistentes como artistas.

select distinct p.idPersona, p.nombreP, p.ap1
from persona p
inner join artista ar on p.idPersona = ar.idPersona
inner join asistente a on p.idPersona = a.idPersona;

-- Consulta 9
-- Top 3 de eventos según su ratio calidad/precio.

select nombEvento, ratio_calidad_precio
from (select e.nombEvento,
	  round(avg(a.valoracion) / e.precioEv, 3) ratio_calidad_precio,
	  dense_rank() over (
	  order by avg(a.valoracion) / e.precioEv desc)  posicion
    from eventos e
    inner join asistente a on e.idEvento = a.idEvento
    where a.valoracion is not null
    group by e.idEvento
) t
where posicion <= 3;

-- Consulta 10
-- Eventos con recaudación estimada superior a la media y valoración >= 4

select nombEvento, ubicacion, actividad, fecha,
       num_asistentes, valoracion_media, recaudacion_estimada
from resumen_eventos
where recaudacion_estimada > (
          select avg(recaudacion_estimada) 
          from resumen_eventos
      )
  and valoracion_media >= 4
order by recaudacion_estimada desc;






