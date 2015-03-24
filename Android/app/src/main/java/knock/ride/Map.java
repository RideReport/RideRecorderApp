package knock.ride;

        import android.app.AlertDialog;
        import android.content.DialogInterface;
        import android.content.Intent;
        import android.net.Uri;
        import android.os.Bundle;
        import android.provider.Settings;
        import android.support.v7.app.ActionBarActivity;
        import android.text.TextUtils;
        import android.view.Menu;
        import android.view.MenuInflater;
        import android.view.MenuItem;
        import android.view.View;
        import android.widget.Button;
        import com.mapbox.mapboxsdk.api.ILatLng;
        import com.mapbox.mapboxsdk.geometry.BoundingBox;
        import com.mapbox.mapboxsdk.geometry.LatLng;
        import com.mapbox.mapboxsdk.overlay.Icon;
        import com.mapbox.mapboxsdk.overlay.Marker;
        import com.mapbox.mapboxsdk.overlay.UserLocationOverlay;
        import com.mapbox.mapboxsdk.tileprovider.tilesource.*;
        import com.mapbox.mapboxsdk.views.MapView;
        import com.mapbox.mapboxsdk.views.util.TilesLoadedListener;

public class Map extends ActionBarActivity {

    private MapView mv;
    private UserLocationOverlay myLocationOverlay;
    private String currentMap = null;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        setContentView(R.layout.activity_map);

        mv = (MapView) findViewById(R.id.mapview);
        mv.setTileSource(new MapboxTileLayer("quicklywilliam.l4imi65m"));
        mv.setMinZoomLevel(mv.getTileProvider().getMinimumZoomLevel());
        mv.setMaxZoomLevel(mv.getTileProvider().getMaximumZoomLevel());
        mv.setCenter(mv.getTileProvider().getCenterCoordinate());
        mv.setZoom(0);
        currentMap = getString(R.string.streetMapId);

        // Show user location (purposely not in follow mode)
        mv.setUserLocationEnabled(true);

        mv.loadFromGeoJSONURL("http://ride.report/trips");


        mv.setOnTilesLoadedListener(new TilesLoadedListener() {
            @Override
            public boolean onTilesLoaded() {
                return false;
            }

            @Override
            public boolean onTilesLoadStarted() {
                // TODO Auto-generated method stub
                return false;
            }
        });
        mv.setVisibility(View.VISIBLE);
    }


    public LatLng getMapCenter() {
        return mv.getCenter();
    }

    public void setMapCenter(ILatLng center) {
        mv.setCenter(center);
    }
}