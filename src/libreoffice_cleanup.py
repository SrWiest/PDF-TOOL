# Script para limpar processos do LibreOffice travados
# Usado após timeouts para garantir que não fiquem processos órfãos

import time
import psutil

def kill_libreoffice_processes():
    """
    Mata todos os processos do LibreOffice que possam ter ficado travados.
    Usado após timeouts para limpeza.
    """
    killed = 0
    process_names = ['soffice.exe', 'soffice.bin', 'LibreOfficePortable.exe']
    
    try:
        for proc in psutil.process_iter(['pid', 'name', 'cmdline']):
            try:
                proc_name = proc.info['name']
                if proc_name and any(name.lower() in proc_name.lower() for name in process_names):
                    # Verificar se é processo headless (para não matar LibreOffice desktop do usuário)
                    cmdline = proc.info.get('cmdline', [])
                    if cmdline and any('--headless' in arg for arg in cmdline):
                        print(f"   [cleanup] Matando processo LibreOffice travado: PID {proc.info['pid']}")
                        proc.kill()
                        killed += 1
                        time.sleep(0.1)  # Pequena pausa entre kills
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                continue
    except Exception as e:
        print(f"   [cleanup] Erro ao limpar processos: {e}")
    
    if killed > 0:
        print(f"   [cleanup] {killed} processo(s) do LibreOffice removido(s)")
        time.sleep(1)  # Aguardar processos terminarem completamente
    
    return killed

if __name__ == "__main__":
    # Pode ser executado standalone para limpeza manual
    killed = kill_libreoffice_processes()
    print(f"Limpeza concluída. {killed} processos removidos.")
