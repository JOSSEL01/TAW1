/*
¿Qué es un decorador de propiedad?

Un decorador de propiedad es una función que se coloca encima de una
propiedad de una clase usando el símbolo @. Se utiliza para agregar
información o comportamiento relacionado con esa propiedad.

En este ejemplo, el decorador @Obligatoria marca una propiedad como
obligatoria y muestra su nombre en la consola.
*/

// Un decorador de propiedad recibe el prototipo de la clase
// y el nombre de la propiedad decorada.
function Obligatoria(
  objetivo: object,
  nombrePropiedad: string | symbol
): void {
  console.log(
    `La propiedad "${String(nombrePropiedad)}" está marcada como obligatoria.`
  );
}

class Usuario {
  // El decorador se aplica a la propiedad "nombre".
  @Obligatoria
  nombre: string;

  constructor(nombre: string) {
    this.nombre = nombre;
  }
}

// Creamos un objeto de la clase Usuario.
const usuario = new Usuario("Lucía");

// Mostramos el valor de la propiedad.