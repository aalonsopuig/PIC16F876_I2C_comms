<html>

<head>
<meta http-equiv="Content-Language" content="es">
<meta name="GENERATOR" content="Microsoft FrontPage 4.0">
<meta name="ProgId" content="FrontPage.Editor.Document">
</head>


<font size="4"><b><i>Comunicaciones I<sup>2</sup>C
      Maestro-Esclavo mediante microcontroladores PIC de gama media.&nbsp;</i></b></font>
      <p>Por Alejandro Alonso Puig<br>
      Agosto 2.003<br>
 <hr>
<p align="justify"><br>
El bus I<sup>2</sup>C es un medio de comunicación serie standard mediante dos hilos
desarrollado por Philips para
intercomunicar microcontroladores, memorias, sensores, displays, etc. Todos los
dispositivos han de ser compatibles con el bus I<sup>2</sup>C aunque sean de marcas
diferentes. 
<p align="justify">En este repositorio podrás encontrar código para el Master y para los Slaves
(caso de que los slaves sean también microcontroladores). Permite comunicación
bidireccional. Está preparado y probado para micros PIC16F876, pero con
pequeños cambios es transportable a otras versiones de PIC con SSP (I<sup>2</sup>C)
implementado. Yo lo he probado con un master y 6 slaves. El programa no está
preparado para el funcionamiento en modo multimaster o multitramas. Solo está
preparado para enviar y recibir un byte por mensaje.</p>
<p align="justify">En este repositorio, además del código fuente, encontrarás imágenes del montaje 
que se propone, así como el esquema electrónico (JPG e Eagle).</p>
<p align="justify">Algunas aclaraciones para utilizar adecuadamente el código:</p>
<p align="justify">&nbsp;</p>
<ol>
  <li>
    <p align="justify"><b>Programa mi2c06_master.asm</b> (Master I<sup>2</sup>C v06 del programa):</li>
</ol>
  <p align="justify">Velocidad reloj I<sup>2</sup>C (línea SCL): El programa está configurado para una
  velocidad de 100Khz (Si el cristal del chip es de 4Mhz). Se puede variar
  modificando el dato de la constante &quot;ClockValue&quot; al principio del
  programa (Cuanto mayor sea el valor, más lento será el reloj I2C)</p>
  <p align="justify">Para enviar un dato al Slave solo hay que cargar la dirección del Slave al
  que se quiere enviar el dato en &quot;DirSlave&quot;, poner el dato en la
  variable &quot;MensajeOut&quot; y llamar a la rutina &quot;Enviar&quot; (call
  Enviar)</p>
  <p align="justify">Para solicitar un dato al Slave solo hay que cargar la dirección del Slave
  al que se quiere solicitar el dato y llamar a la rutina &quot;Recibir&quot;
  (call Recibir). Tras su ejecución, el dato estará en la variable
  &quot;MensajeIn&quot;</p>
  <p align="justify">El programa incluye código de ejemplo que manda al Slave de dirección
  &quot;01111000&quot; un dato &quot;10101010&quot; y le pide un dato que saca
  por el puerto B al que hay conectado una barrera de leds:</p>
  <p align="justify">&nbsp;</p>
  <p><font face="Courier New" color="#000080" size="2">MLoop<br>
  &nbsp; ;ENVIO DE UN BYTE AL SLAVE<br>
  &nbsp; movlw&nbsp;&nbsp;&nbsp; b'10101010' ;dato cualquiera por
  I2C que metemos en...<br>
  &nbsp; movwf &nbsp;&nbsp; MensajeOut&nbsp; ;...&quot;MensajeOut&quot;
  para envío por I2C<br>
  &nbsp; movlw &nbsp;&nbsp; b'01111000' ;Establece dirección de
  envío..<br>
  &nbsp; Movwf &nbsp;&nbsp; DirSlave &nbsp;&nbsp; ;..es decir,
  dirección del slave<br>
  &nbsp; call &nbsp;&nbsp;&nbsp; Enviar &nbsp;&nbsp;&nbsp;&nbsp; ;Envía
  el dato de &quot;MensajeOut&quot; al Slave<br><br>

  &nbsp; ;PETICION DE UN BYTE DE DATOS AL SLAVE<br>
  &nbsp; movlw &nbsp;&nbsp; b'01111000' ;Establece dirección de
  solicitud..<br>
  &nbsp; Movwf &nbsp;&nbsp; DirSlave &nbsp;&nbsp; ;..es decir,
  dirección del slave<br>
  &nbsp; call &nbsp;&nbsp;&nbsp; Recibir &nbsp;&nbsp;&nbsp; ;Toma
  dato del Slave...<br>
  &nbsp; movf &nbsp;&nbsp;&nbsp; MensajeIn,W ;... a través de &quot;MensajeIn&quot;...<br>
  &nbsp; movwf &nbsp;&nbsp; PORTB ;...y lo muestra por
  PORTB (Leds)<br>
  &nbsp; goto &nbsp;&nbsp;&nbsp; MLoop</font></p>

<font SIZE="2">
<p>&nbsp;</p>
<p>&nbsp;</p>
</font>
<ol start="2">
  <li><b>Programa si2c06_slave.asm</b> (Slave I<sup>2</sup>C v06 del programa):</li>
</ol>
  <p align="justify">Dirección del Slave: Se ha de establecer en la constante
  &quot;DirNodo&quot; al principio del programa. Por defecto está puesta la
  dirección &quot;'01111000&quot;</p>
  <p align="justify">El programa trabaja mediante interrupción SSP. Es decir que cuando le
  llega un comando del Master, salta a la rutina de interrupción y lo procesa.
  Si es un byte que envía el Master al Slave, la rutina se ocupa de guardarlo
  en la variable &quot;MensajeIn&quot;. Si en cambio es una solicitud de dato,
  el Slave le enviará al Master lo que tenga en ese momento en la variable
  &quot;MensajeOut&quot;</p>
  <p align="justify">El programa incluye en el cuerpo del mismo código de ejemplo que envía al
  Master (cuando éste le solicita información) el valor &quot;10011001&quot; y
  cuando el Master le envía un dato , lo muestra por la barrera de leds
  conectada al puerto B</p>

  <p><font face="Courier New" color="#000080" size="2">MLoop<br>
  &nbsp; movlw b'10011001' ;dato cualquiera por I2C que metemos
  en...<br>
  &nbsp; movwf MensajeOut&nbsp; ;...&quot;MensajeOut&quot; para
  cuando el Master se lo pida<br>
  &nbsp; movf&nbsp; MensajeIn,W ;Muestra por port B (leds)...<br>
  &nbsp; movwf PORTB &nbsp;&nbsp;&nbsp;&nbsp;&nbsp; ;...el ultimo
  valor enviado por el Master<br>
  &nbsp; goto&nbsp; MLoop</font></p>

  <p>&nbsp;</p>
  <p><b><u>Descargas</u></b></p>
<ul>
  <li><a href="mi2c06_master.asm" target="_blank">Programa
  Master</a>&nbsp;<font size="1"> (.ASM 12Kb)</font></li>
  <li><a href="si2c06_slave.asm" target="_blank">Programa Slave</a> <font size="1">(.ASM
    9Kb)</font></li>
  <li><a href="i2cBoard.jpg" target="_blank">Imagen del montaje</a> <font size="1">(.JPG
    63Kb)&nbsp;</font></li>
  <li><a href="I2CMaster-Slave.sch" target="_blank">Esquema electrónico</a> <font size="1">(Formato
    Eagle .SCH 122Kb)</font></li>
  <li><a href="i2cSch.jpg" target="_blank">Esquema electrónico</a> <font size="1">(.JPG
    116Kb)</font></li>
  <li><a href="i2cSignal.jpg" target="_blank">Gráfico Señales I2C</a> <font size="1">(.JPG&nbsp;
    47Kb)</font></li>
</ul>
  <p>&nbsp;</p>
  <p><b>LINKS RELACIONADOS</b></p>
  <ul>
    <li><a href="http://www.microchip.com/1010/pline/picmicro/category/embctrl/14kbytes/devices/16f876/index.htm" target="_blank">PIC16F87x
      Datasheet</a></li>
    <li><a href="http://www.microchip.com/download/appnote/pic16/00734a.pdf" target="_blank">Using
      the PICmicro SSP for Slave I2CTM Communication</a>  <font size="1">(PDF )</font></li>
    <li><a href="http://www.microchip.com/download/appnote/pic16/00735a.pdf" target="_blank">Using
      the PICmicro MSSP Module for Master I2C Communications</a><a href="http://www.microchip.com/download/appnote/pic16/00734a.pdf" target="_blank"></a>
      <font size="1">(PDF )</font></li>
    <li><a href="http://www.semiconductors.philips.com/buses/i2c/" target="_blank">Página
      I2C de Philips</a></li>
  </ul>

<hr>


</body>

</html>
