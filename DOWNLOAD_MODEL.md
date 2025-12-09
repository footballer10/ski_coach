# Download Llama 3.1 8B Instruct Model

## Option 1: Direct Browser Download (Recommended for large files)

1. Go to: https://huggingface.co/bartowski/Meta-Llama-3.1-8B-Instruct-GGUF
2. Click on "Files and versions"
3. Find and download: `Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf` (~4.9 GB)
4. Rename it to: `llama-3.1-8b-instruct-q4_k_m.gguf`
5. Move it to: `c:\flutter_projects\ski_coach\assets\models\`

## Option 2: PowerShell Command (may be unreliable for large files)

Run this in PowerShell (it will take several minutes):

```powershell
$ProgressPreference = 'Continue'
Invoke-WebRequest -Uri "https://huggingface.co/bartowski/Meta-Llama-3.1-8B-Instruct-GGUF/resolve/main/Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf" -OutFile "c:\flutter_projects\ski_coach\assets\models\llama-3.1-8b-instruct-q4_k_m.gguf"
```

## Option 3: Using wget (if installed)

```powershell
wget https://huggingface.co/bartowski/Meta-Llama-3.1-8B-Instruct-GGUF/resolve/main/Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf -O c:\flutter_projects\ski_coach\assets\models\llama-3.1-8b-instruct-q4_k_m.gguf
```

## Verify Download

After download completes, verify the file size:

```powershell
Get-ChildItem "c:\flutter_projects\ski_coach\assets\models\llama-3.1-8b-instruct-q4_k_m.gguf" | Select-Object Name, @{Name="Size(GB)";Expression={[math]::Round($_.Length/1GB, 2)}}
```

Should show approximately **4.66 GB**.

## Remove Old Model

Once the new model is downloaded and verified, remove the old 3B model:

```powershell
Remove-Item "c:\flutter_projects\ski_coach\assets\models\llama-3.2-3b-instruct-q4_k_m.gguf" -Force
```

---

**Note:** The code has already been updated to use the new model filename. Once you download it, the app will use Llama 3.1 8B automatically.
