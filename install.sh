SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 解析参数：第一个位置参数为虚拟机名称（未指定时使用默认值），支持 --capacity 选项
VM_NAME="Rocky-Linux"
CAPACITY=""
NAME_SET=0
IMG_FILENAME="Rocky-10-GenericCloud-LVM-10.2-20260525.0.x86_64.qcow2"
IMG_LIBVIRT_DIR="/var/lib/libvirt/images"
IMG_LIBVIRT_PATH="$IMG_LIBVIRT_DIR/$IMG_FILENAME"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --capacity)
      if [[ -z "$2" ]]; then
        echo "错误：--capacity 需要一个参数（例如 --capacity 100G）。" >&2
        exit 1
      fi
      CAPACITY="$2"
      shift 2
      ;;
    -*)
      echo "错误：未知选项 $1（支持 --capacity 大小，例如 --capacity 100G）。" >&2
      exit 1
      ;;
    *)
      if (( NAME_SET )); then
        echo "错误：多余的参数 $1。" >&2
        exit 1
      fi
      VM_NAME="$1"
      NAME_SET=1
      shift
      ;;
  esac
done

bash "$SCRIPT_DIR/undefine.sh" "$VM_NAME"

# 用 genisoimage 从 cloud-init 数据文件重新生成 cidata.iso
if ! command -v genisoimage >/dev/null 2>&1; then
  echo "错误：未找到 genisoimage，请先安装（例如 sudo apt install genisoimage）。" >&2
  exit 1
fi
rm -f "$SCRIPT_DIR/cidata.iso"
genisoimage -output "$SCRIPT_DIR/cidata.iso" -volid cidata -joliet -rock \
  "$SCRIPT_DIR/meta-data" "$SCRIPT_DIR/network-config" "$SCRIPT_DIR/user-data"

sudo cp "$HOME/OS/$IMG_FILENAME" "$IMG_LIBVIRT_DIR/"
sudo cp "$SCRIPT_DIR/cidata.iso" "$IMG_LIBVIRT_DIR/"

# 如果指定了 --capacity，扩容复制后的 qcow2 镜像  
if [[ -n "$CAPACITY" ]]; then
  if ! command -v qemu-img >/dev/null 2>&1; then
    echo "错误：未找到 qemu-img，请先安装（例如 sudo apt install qemu-utils）。" >&2
    exit 1
  fi
  echo "正在将镜像扩容到 $CAPACITY ..."
  sudo qemu-img resize "$IMG_LIBVIRT_PATH" "$CAPACITY"
fi

sudo virt-install \
  --name "$VM_NAME" \
  --os-variant rocky10 \
  --memory 6144 \
  --vcpus 6 \
  --disk path="$IMG_LIBVIRT_PATH",format=qcow2,bus=virtio \
  --disk path="$IMG_LIBVIRT_DIR/cidata.iso",device=cdrom,bus=sata \
  --network default,model=virtio \
  --import \
  --noautoconsole

