// Interface
interface IFigura {
  area(): number;
  perimetro(): number;
}

// Clase Circulo
class Circulo implements IFigura {
  public radio: number;

  constructor(radio: number) {
    this.radio = radio;
  }

  area(): number {
    return Math.PI * Math.pow(this.radio, 2);
  }

  perimetro(): number {
    return 2 * Math.PI * this.radio;
  }

  toString(): string {
    return `Circulo [radio=${this.radio}, area=${this.area().toFixed(2)}, perimetro=${this.perimetro().toFixed(2)}]`;
  }
}

// Clase Rectangulo
class Rectangulo implements IFigura {
  public base: number;
  public altura: number;

  constructor(base: number, altura: number) {
    this.base = base;
    this.altura = altura;
  }

  area(): number {
    return this.base * this.altura;
  }

  perimetro(): number {
    return 2 * (this.base + this.altura);
  }

  toString(): string {
    return `Rectangulo [base=${this.base}, altura=${this.altura}, area=${this.area()}, perimetro=${this.perimetro()}]`;
  }
}

// Clase Pentagono (Pentágono regular)
class Pentagono implements IFigura {
  public lado: number;

  constructor(lado: number) {
    this.lado = lado;
  }

  area(): number {
    // Apotema para un pentágono regular: ap = lado / (2 * tan(180° / 5))
    const apotema = this.lado / (2 * Math.tan(Math.PI / 5));
    return (this.perimetro() * apotema) / 2;
  }

  perimetro(): number {
    return 5 * this.lado;
  }

  toString(): string {
    return `Pentagono [lado=${this.lado}, area=${this.area().toFixed(2)}, perimetro=${this.perimetro().toFixed(2)}]`;
  }
}

// Ejemplo de uso:
const figuras: IFigura[] = [
  new Circulo(5),
  new Rectangulo(4, 6),
  new Pentagono(3)
];

figuras.forEach((figura) => {
  console.log(figura.toString());
});
