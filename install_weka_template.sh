INSTALLATION_PATH="/tmp/weka"
mkdir -p $INSTALLATION_PATH
cd $INSTALLATION_PATH

echo "$(date -u): before weka agent installation"

# install weka
TOKEN=${get_weka_io_token}
INSTALL_URL=https://$TOKEN@get.weka.io/dist/v1/install/${weka_version}/${weka_version}

if [[ "${install_weka_url}" ]]; then
    wget -P $INSTALLATION_PATH "${install_weka_url}"
    IFS='/' read -ra tar_str <<< "\"${install_weka_url}\""
    pkg_name=$(cut -d'/' -f"$${#tar_str[@]}" <<< "${install_weka_url}")
    cd $INSTALLATION_PATH
    tar -xvf $pkg_name
    tar_folder=$(echo $pkg_name | sed 's/.tar//')
    cd $INSTALLATION_PATH/$tar_folder
    ./install.sh
  else
    retry 300 2 curl --fail --max-time 10 $INSTALL_URL | sh
fi

echo "$(date -u): weka agent installation complete"
