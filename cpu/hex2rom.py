import sys
import struct
import argparse

def main():
    parser = argparse.ArgumentParser(description="Convierte un archivo con instrucciones en hexadecimal a un archivo binario ROM.")
    parser.add_argument("input", help="Archivo de texto con instrucciones en hexadecimal (una por línea)")
    parser.add_argument("output", help="Archivo binario de salida (.rom o .bin)")
    parser.add_argument("--big-endian", action="store_true", help="Usar Big-Endian (por defecto es Little-Endian)")
    args = parser.parse_args()

    endian_fmt = ">I" if args.big_endian else "<I"

    try:
        with open(args.input, "r") as fin, open(args.output, "wb") as fout:
            line_count = 0
            for line in fin:
                # Remover comentarios y espacios
                line = line.split(";")[0].split("#")[0].strip()
                if not line:
                    continue
                
                # Convertir a entero
                try:
                    # Soporta formato "0x..." o simplemente "..."
                    inst = int(line, 16)
                except ValueError:
                    print(f"Error parseando la línea: '{line}'")
                    sys.exit(1)
                
                # Empaquetar y escribir
                fout.write(struct.pack(endian_fmt, inst))
                line_count += 1
                
            print(f"Éxito: {line_count} instrucciones escritas en {args.output} ({'Big' if args.big_endian else 'Little'}-Endian).")
            
    except FileNotFoundError:
        print(f"Error: No se pudo encontrar el archivo {args.input}")
        sys.exit(1)
    except Exception as e:
        print(f"Error inesperado: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
